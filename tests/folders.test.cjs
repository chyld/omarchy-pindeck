const {test}=require('node:test');
const assert=require('node:assert/strict');
const F=require('../domain/Folders.js');
const {command}=require('../domain/Launch.js');
const apps=[{id:'a',name:'A',actions:[{id:'new'}]},{id:'b',name:'B',runInTerminal:true}];
const pins=apps.map(({id,name})=>({id,name}));
test('legacy pins and orphaned folder memberships remain visible',()=>{
 assert.deepEqual(F.rows(pins,[],apps),apps);
 assert.deepEqual(F.rows(F.move(pins,'a','gone'),[],apps),apps);
});
test('folders collapse independently and preserve native launches and actions',()=>{
 const moved=F.move(pins,'a','work');
 const folder={id:'work',name:'Work',expanded:true};
 const rows=F.rows(moved,[folder],apps);
 assert.equal(rows[0],apps[1]);
 assert.equal(rows[1].count,1);
 assert.equal(rows[2],apps[0]);
 assert.deepEqual(command(rows[2],'new'),command(apps[0],'new'));
 assert.equal(F.rows(moved,[{...folder,expanded:false}],apps).length,2);
 assert.equal(pins[0].folderId,undefined);
});
test('serialized settings retain order, membership, and expansion',()=>{
 const state=JSON.parse(JSON.stringify({pins:F.move(pins,'b','work'),folders:[{id:'empty',name:'Empty',expanded:false},{id:'work',name:'Work',expanded:true}]}));
 const rows=F.rows(state.pins,state.folders,apps);
 assert.deepEqual(rows.map(r=>r.id),['a','empty','work','b']);
 assert.equal(rows[1].expanded,false);
 assert.deepEqual(command(rows[3],''),command(apps[1],''));
});
test('deleting a group removes its pins and preserves other groups without mutating input',()=>{
 const moved=F.move(pins,'a','work');
 const state=F.remove(moved,[{id:'work'},{id:'other'}],'work');
 assert.deepEqual(state.pins.map(p=>p.id),['b']);
 assert.deepEqual(state.folders,[{id:'other'}]);
 assert.equal(moved[0].folderId,'work');
});
test('moving between folders or to top level never duplicates or loses missing apps',()=>{
 let state=pins.concat([{id:'gone',name:'Uninstalled',icon:'old'}]);
 state=F.move(F.move(state,'gone','one'),'gone','two');
 const rows=F.rows(state,[{id:'one'},{id:'two'}],apps);
 assert.equal(rows.filter(r=>r.id==='gone').length,1);
 assert.equal(rows.at(-1).missing,true);
 assert.equal(F.move(state,'gone','').length,3);
});
test('dragging supports mixed top-level app and folder ordering after reload',()=>{
 const folders=[{id:'one',expanded:false},{id:'two'}];
 let state=F.drop(pins,folders,[],{id:'two',folder:true},{id:'a'},'before');
 state=JSON.parse(JSON.stringify(state));
 assert.deepEqual(F.rows(state.pins,state.folders,apps,state.order).map(r=>r.id),['two','a','b','one']);
 state=F.drop(state.pins,state.folders,state.order,{id:'b'},{id:'a'},'before');
 assert.deepEqual(F.rows(state.pins,state.folders,apps,state.order).map(r=>r.id),['two','b','a','one']);
});
test('dragging into folders expands them and dragging out restores top-level membership',()=>{
 let state=F.drop(pins,[{id:'one',expanded:false}],[],{id:'a'},{id:'one',folder:true},'inside');
 assert.equal(state.pins.find(p=>p.id==='a').folderId,'one');
 assert.equal(state.folders[0].expanded,true);
 assert.deepEqual(state.order,['app:b','folder:one']);
 state=F.drop(state.pins,state.folders,state.order,{id:'a'},null,'end');
 assert.equal(state.pins.find(p=>p.id==='a').folderId,'');
 assert.deepEqual(state.order,['app:b','folder:one','app:a']);
});
test('child reordering and transfers retain exactly one copy of every pin',()=>{
 const folders=[{id:'one'},{id:'two'}];
 let state=F.drop(F.move(pins,'a','one'),folders,[],{id:'b'},{id:'a'},'before');
 assert.deepEqual(state.pins.map(p=>p.id),['b','a']);
 assert.equal(state.pins[0].folderId,'one');
 state=F.drop(state.pins,state.folders,state.order,{id:'b'},{id:'two',folder:true},'inside');
 assert.equal(state.pins.find(p=>p.id==='b').folderId,'two');
 assert.equal(new Set(state.pins.map(p=>p.id)).size,2);
});
test('folder drags keep children and prohibit nesting or dropping onto own child',()=>{
 const nested=F.move(pins,'a','one'), folders=[{id:'one'},{id:'two'}];
 assert.equal(F.drop(nested,folders,[],{id:'one',folder:true},{id:'two',folder:true},'inside'),null);
 assert.equal(F.drop(nested,folders,[],{id:'one',folder:true},{id:'a'},'after'),null);
 const state=F.drop(nested,folders,[],{id:'two',folder:true},{id:'a'},'before');
 assert.deepEqual(state.order,['app:b','folder:two','folder:one']);
 assert.deepEqual(state.pins,nested);
});
test('stale ordering removes deleted entries and appends new pins without loss',()=>{
 assert.deepEqual(F.rootOrder(pins,[{id:'one'}],['app:b','app:b','app:gone']),['app:b','app:a','folder:one']);
 const moved=F.move(pins,'a','one');
 const removed=F.remove(moved,[{id:'one'}],'one');
 assert.deepEqual(F.rootOrder(removed.pins,removed.folders,['app:b','folder:one']),['app:b']);
});
test('directory shortcuts retain paths when grouped and are removed with their group',()=>{
 const shortcut={id:'location:/home/user/My Photos',kind:'location',path:'/home/user/My Photos',name:'Photos',icon:'folder'};
 const all=pins.concat([shortcut]);
 assert.equal(F.rows(all,[],apps).at(-1),shortcut);
 let state=F.drop(all,[{id:'group'}],[],shortcut,{id:'group',folder:true},'inside');
 let row=F.rows(state.pins,state.folders,apps,state.order).at(-1);
 assert.equal(row.path,shortcut.path);
 assert.equal(row.missing,undefined);
 state=F.remove(state.pins,state.folders,'group');
 row=F.rows(state.pins,state.folders,apps).find(r=>r.id===shortcut.id);
 assert.equal(row,undefined);
 assert.deepEqual(state.pins,pins);
});
test('copies of the same app have independent identity, movement and removal',()=>{
 const copies=[{id:'a',name:'A'}, {id:'a',pinId:'copy1',folderId:'one'}, {id:'a',pinId:'copy2',folderId:'two'}];
 const folders=[{id:'one'},{id:'two'},{id:'three'}];
 const rendered=F.rows(copies,folders,apps);
 assert.deepEqual(rendered.filter(r=>!r.folder).map(F.key),['a','copy1','copy2']);
 const moved=F.move(copies,'copy1','three');
 assert.equal(moved[0].folderId,undefined);
 assert.equal(moved[1].folderId,'three');
 assert.equal(moved[2].folderId,'two');
 assert.deepEqual(moved.filter(p=>F.key(p)!=='copy1').map(F.key),['a','copy2']);
 assert.equal(F.move(copies,'copy1','two'),null);
 assert.equal(F.move(copies,'copy1',''),null);
 assert.deepEqual(command(rendered.find(r=>r.pinId==='copy2'),'new'),command(apps[0],'new'));
});
test('dragging a copy rejects duplicates and preserves the other copies',()=>{
 const copies=[{id:'a',pinId:'first',folderId:'one'},{id:'a',pinId:'second',folderId:'two'}];
 const groups=[{id:'one'},{id:'two'}];
 assert.equal(F.drop(copies,groups,[],copies[0],{id:'two',folder:true},'inside'),null);
 const state=F.drop(copies,groups,[],copies[0],null,'end');
 assert.equal(state.pins.find(p=>p.pinId==='second').folderId,'two');
 assert.equal(state.pins.find(p=>p.pinId==='first').folderId,'');
 assert.ok(state.order.includes('app:first'));
 const restored=JSON.parse(JSON.stringify(state));
 assert.equal(F.rows(restored.pins,restored.folders,apps,restored.order).filter(r=>r.id==='a').length,2);
});
test('deleting a group keeps existing top-level copy and all copies in other groups',()=>{
 const copies=[{id:'a'},{id:'a',pinId:'one',folderId:'one'},{id:'a',pinId:'two',folderId:'two'},{id:'b',pinId:'b-one',folderId:'one'}];
 const result=F.remove(copies,[{id:'one'},{id:'two'}],'one');
 assert.deepEqual(result.pins.map(F.key),['a','two']);
 assert.equal(result.pins[1].folderId,'two');
});
test('same-path directory copies have independent labels, moves and removal',()=>{
 const id='location:/home/user/Photos';
 const copies=[{id,kind:'location',path:'/home/user/Photos',name:'Photos'},
  {id,pinId:'work-photos',kind:'location',path:'/home/user/Photos',name:'Work photos',folderId:'work'},
  {id,pinId:'personal-photos',kind:'location',path:'/home/user/Photos',name:'Personal photos',folderId:'personal'}];
 const groups=[{id:'work'},{id:'personal'},{id:'archive'}];
 const renamed=copies.map(p=>F.key(p)==='work-photos'?{...p,name:'Reference'}:p);
 assert.deepEqual(F.rows(renamed,groups,[]).filter(r=>r.kind==='location').map(r=>r.name),['Photos','Reference','Personal photos']);
 assert.equal(F.move(copies,'work-photos','personal'),null);
 assert.equal(F.move(copies,'work-photos',''),null);
 const moved=F.drop(renamed,groups,[],renamed[1],{id:'archive',folder:true},'inside');
 assert.equal(moved.pins.find(p=>p.pinId==='work-photos').folderId,'archive');
 assert.equal(moved.pins.find(p=>p.pinId==='personal-photos').folderId,'personal');
 assert.equal(moved.pins.filter(p=>F.key(p)!=='work-photos').length,2);
 const deleted=F.remove(copies,groups,'work');
 assert.deepEqual(deleted.pins.map(F.key),[id,'personal-photos']);
});
test('command pins preserve their command when grouped and are removed with their group',()=>{
 const pin={id:'cmd',pinId:'cmd',kind:'command',name:'Downloads',commandText:'eza -a -l ~/Downloads',runInTerminal:true};
 let state=F.drop([pin],[{id:'g'}],[],pin,{id:'g',folder:true},'inside');
 const rendered=F.rows(state.pins,state.folders,[]);
 assert.equal(rendered[1].commandText,pin.commandText);
 assert.equal(rendered[1].missing,undefined);
 state=F.remove(state.pins,state.folders,'g');
 assert.deepEqual(state.pins,[]);
 assert.deepEqual(state.folders,[]);
});

const {test}=require('node:test');
const assert=require('node:assert/strict');
const {command}=require('../Launch.js');
test('normal launch uses the same GUI behavior for every app, including Files',()=>{
 for (const id of ['org.gnome.Nautilus','chromium','App With Spaces'])
  assert.deepEqual(command({id},''),['uwsm-app','--','gtk-launch',id+'.desktop']);
});
test('all advertised action IDs are supported without app-specific rules',()=>{
 const entry={id:'example',actions:[{id:'new-window'},{id:'private-window'},{id:'compose'}]};
 for (const action of entry.actions)
  assert.deepEqual(command(entry,action.id),['uwsm-app','-t','service','--','example.desktop:'+action.id]);
 assert.equal(command(entry,'not-advertised'),null);
});
test('terminal apps and their actions retain terminal launch behavior',()=>{
 const e={id:'terminal-app',runInTerminal:true,actions:[{id:'action'}]};
 assert.deepEqual(command(e,''),['uwsm-app','-t','service','-T','--','terminal-app.desktop']);
 assert.deepEqual(command(e,'action'),['uwsm-app','-t','service','-T','--','terminal-app.desktop:action']);
});
test('missing apps and apps without actions cannot run an action',()=>{
 assert.equal(command({id:'gone',missing:true},''),null);
 assert.equal(command({id:'plain'},'new-window'),null);
});
test('group launch includes only installed apps in pinned order, regardless of collapse',()=>{
 const {groupEntries}=require('../Launch.js');
 const apps=[{id:'terminal',runInTerminal:true},{id:'gui'}];
 const pins=[{id:'gui',folderId:'g'},{id:'gone',folderId:'g'},{id:'location:/tmp',kind:'location',folderId:'g'},{id:'terminal',folderId:'g'},{id:'gui',folderId:'g'},{id:'outside',folderId:'other'}];
 const entries=groupEntries(pins,apps,'g');
 assert.deepEqual(entries.map(e=>e.id),['gui','terminal']);
 assert.deepEqual(entries.map(e=>command(e,'')),[['uwsm-app','--','gtk-launch','gui.desktop'],['uwsm-app','-t','service','-T','--','terminal.desktop']]);
 assert.deepEqual(groupEntries(pins,apps,'empty'),[]);
 assert.deepEqual(groupEntries(pins,apps,''),[]);
});
test('saved commands run literally through Bash and keep terminal open after exit',()=>{
 const {spawnSync}=require('node:child_process');
 const value='printf "result: %s\\n" "a b; $(printf safe)"; exit 7';
 const args=command({id:'cmd',kind:'command',commandText:value},'');
 assert.deepEqual(args.slice(0,6),['uwsm-app','--','xdg-terminal-exec','--','bash','-lc']);
 assert.equal(args.at(-1),value);
 const result=spawnSync('bash',args.slice(5),{input:'\n',encoding:'utf8'});
 assert.match(result.stdout,/result: a b; safe/);
 assert.match(result.stdout,/Exit status: 7/);
 assert.match(result.stdout,/Press Enter to close/);
 assert.equal(command({id:'cmd',kind:'command',commandText:'   '},''),null);
 assert.equal(command({id:'cmd',kind:'command',commandText:'echo ok'},'action'),null);
});
test('group launch runs command-only and mixed groups using the normal command terminal',()=>{
 const {groupEntries}=require('../Launch.js');
 const cmd={id:'saved',kind:'command',commandText:'eza -a -l ~/Downloads',runInTerminal:true,folderId:'def'};
 assert.deepEqual(groupEntries([cmd],[],'def'),[cmd]);
 const entries=groupEntries([{id:'gui',folderId:'def'},cmd,{id:'location:/tmp',kind:'location',folderId:'def'},{id:'gone',folderId:'def'}],[{id:'gui'}],'def');
 assert.deepEqual(entries.map(e=>e.id),['gui','saved']);
 assert.deepEqual(command(entries[1],''),command(cmd,''));
 assert.deepEqual(groupEntries([{...cmd,commandText:' '}],[],'def'),[]);
});
test('group launch includes folder-only and mixed groups with safely encoded paths',()=>{
 const {groupEntries}=require('../Launch.js');
 const folder={id:'location:/tmp/My # Photos',kind:'location',path:'/tmp/My # Photos',folderId:'g'};
 assert.deepEqual(groupEntries([folder],[],'g'),[folder]);
 assert.deepEqual(command(folder,''),['xdg-open','file:///tmp/My%20%23%20Photos']);
 const cmd={id:'cmd',kind:'command',commandText:'echo hello',folderId:'g'};
 assert.deepEqual(groupEntries([{id:'app',folderId:'g'},folder,cmd],[{id:'app'}],'g').map(e=>e.id),['app',folder.id,'cmd']);
 assert.equal(command({...folder,path:''},''),null);
});

const {test}=require('node:test');
const assert=require('node:assert/strict');
const {choose,center}=require('../Focus.js');
const term={id:'cliamp',name:'cliamp',terminal:true};
const gui={id:'org.gnome.Nautilus',name:'Files',startupClass:'org.gnome.Nautilus'};
const old={address:'0x1',class:'foot',mapped:true};
const fresh={address:'0x2',class:'foot',mapped:true};
test('terminal launches select a new terminal, not the existing focused one',()=>{
 assert.equal(choose([old],term,['0x1'],'0x1'),null);
 assert.equal(choose([old,fresh],term,['0x1'],'0x1'),fresh);
});
test('unrelated windows and hidden windows cannot capture launch focus',()=>{
 assert.equal(choose([fresh],gui,[],'0x2'),null);
 assert.equal(choose([{...fresh,hidden:true}],term,[],'0x2'),null);
});
test('existing single-instance GUI window can receive focus',()=>{
 const files={address:'0x3',class:'org.gnome.Nautilus',mapped:true};
 assert.equal(choose([files],gui,['0x3'],'0x3'),files);
 assert.equal(choose([files],gui,['0x3'],'0x1'),null);
});
test('pointer center uses global logical coordinates, including negative monitors',()=>{
 assert.deepEqual(center({at:[-1920,40],size:[1000,800]}),{x:-1420,y:440});
 assert.equal(center({at:[0,0],size:[0,0]}),null);
});
test('explicit new-window launches wait for the new window rather than the existing one',()=>{
 const existing={address:'0x3',class:'org.gnome.Nautilus',mapped:true};
 const created={...existing,address:'0x4'};
 const app={...gui,newWindow:true};
 assert.equal(choose([existing],app,['0x3'],'0x3'),null);
 assert.equal(choose([existing,created],app,['0x3'],'0x3'),created);
});

const {test}=require('node:test');
const assert=require('node:assert/strict');
const F=require('../domain/Folders.js');
const C=require('../domain/Config.js');
const L=require('../domain/Launch.js');
const Focus=require('../domain/Focus.js');

test('5000 deterministic random moves/drops preserve identity, membership and order',()=>{
 let seed=18437;
 const random=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n;};
 let pins=Array.from({length:24},(_,i)=>({id:'app'+(i%8),pinId:'pin'+i,name:'App '+i,folderId:'g'+Math.floor(i/8)}));
 let folders=[0,1,2].map(i=>({id:'g'+i,name:'Group '+i,expanded:true}));
 let order=[];
 for(let step=0;step<5000;step++){
  const previous=JSON.stringify({pins,folders,order});
  const source=pins[random(pins.length)];
  const target=random(3)?folders[random(folders.length)]:null;
  const result=F.drop(pins,folders,order,source,target?{...target,folder:true}:null,target?'inside':'end');
  assert.equal(JSON.stringify({pins,folders,order}),previous,'input mutated');
  if(result){pins=result.pins;folders=result.folders;order=result.order;}
  assert.equal(new Set(pins.map(F.key)).size,24);
  assert.equal(new Set(pins.map(p=>JSON.stringify([p.id,p.folderId||'']))).size,24);
  assert.equal(new Set(order).size,order.length);
  assert.deepEqual(F.rootOrder(pins,folders,order),order);
  assert.equal(F.rows(pins,folders,[],order).filter(r=>!r.folder).length,24);
  C.parse(JSON.stringify({version:1,pinnedApps:pins,folders,rootOrder:order}));
 }
});
test('prototype-like identifiers are ordinary identities',()=>{
 const pins=['__proto__','constructor','toString'].map(id=>({id,name:id}));
 assert.deepEqual(C.parse(JSON.stringify({pinnedApps:pins,folders:[],rootOrder:[]})).pinnedApps,pins);
 const groups=pins.map(p=>({id:p.id,name:p.name}));
 assert.deepEqual(C.parse(JSON.stringify({pinnedApps:[],folders:groups,rootOrder:[]})).folders,groups);
 assert.equal(L.groupEntries(pins.map(p=>({...p,folderId:'g'})),pins,'g').length,3);
});
test('config rejects oversized values, unknown kinds and controls',()=>{
 for(const extra of [{name:'x'.repeat(257)},{kind:'executable'},{path:'/bad\0path'},{commandText:'x'.repeat(16385)}]){
  assert.throws(()=>C.parse(JSON.stringify({pinnedApps:[{id:'x',name:'X',...extra}],folders:[],rootOrder:[]})));
 }
});
test('desktop arguments cannot become options or compositor code',()=>{
 for(const id of ['--help','bad\nname','a/b']) assert.equal(L.command({id},''),null);
 for(const coord of [NaN,Infinity,'1);exec()',1e20]) assert.equal(Focus.center({at:[coord,0],size:[100,100]}),null);
});

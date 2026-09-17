const {test}=require('node:test');const assert=require('node:assert/strict');const {parse}=require('../Config.js');
const base={version:1,pinnedApps:[{id:'code',name:'Code'},{id:'code',pinId:'copy',folderId:'work',name:'Code'}],folders:[{id:'work',name:'Work'}],rootOrder:['app:code','folder:work']};
test('config roundtrip preserves copies, order and extra fields',()=>assert.deepEqual(parse(JSON.stringify({...base,extra:true})),{...base,extra:true}));
test('invalid edits reject instead of replacing good data',()=>{
 for(const value of ['{', '[]', JSON.stringify({...base,pinnedApps:null}), JSON.stringify({...base,version:2}),JSON.stringify({...base,pinnedApps:[...base.pinnedApps,base.pinnedApps[0]]}),JSON.stringify({...base,pinnedApps:[{id:'cmd',name:'Broken',kind:'command'}]})]) assert.throws(()=>parse(value));
});

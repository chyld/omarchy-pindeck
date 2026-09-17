const {test} = require('node:test');
const assert = require('node:assert/strict');
const {score, search} = require('../domain/Search.js');
const apps = [
  {id:'firefox',name:'Firefox'},
  {id:'org.code',name:'Visual Studio Code'},
  {id:'hidden',name:'Hidden',noDisplay:true},
  {id:'cli',name:'CLI',runInTerminal:true}
];
test('subsequence and case-insensitive matching', () => {
  assert.ok(score('Firefox','FFX') >= 0);
  assert.ok(score('Visual Studio Code','vsc') >= 0);
  assert.equal(score('Firefox','fzx'), -1);
});
test('exact and prefix matches outrank scattered letters', () => {
  assert.ok(score('Code','code') > score('Code Editor','code'));
  assert.ok(score('Code Editor','code') > score('Cloud Drive','code'));
});
test('empty search includes GUI and terminal apps, but excludes hidden apps', () => {
  assert.deepEqual(search(apps,'').map(e=>e.id),['cli','firefox','org.code']);
});
test('finder returns intended match and handles no results', () => {
  assert.deepEqual(search(apps,'vsc').map(e=>e.id),['org.code']);
  assert.deepEqual(search(apps,'zzzz'),[]);
});
test('Omarchy exclusions and desktop visibility both filter search results', () => {
  const {hiddenIds} = require('../domain/Search.js');
  const configured = hiddenIds('firefox.desktop\r\n\n');
  const desktop = hiddenIds('org.code\n');
  assert.deepEqual(search(apps, '', configured, desktop).map(e => e.id), ['cli']);
  assert.deepEqual(search(apps, 'firefox', configured, {}), []);
  assert.deepEqual(search(apps, '', {}, desktop).map(e => e.id), ['cli', 'firefox']);
});

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

const source = readFileSync(join(__dirname, '../src/proto-shop-finder/src/datas/DataSelector.js'), 'utf8')
  .replace('import Datas from "./data";', '').replace('export function', 'function');
function load(data) {
  const context = vm.createContext({ Datas: data, console: { log() {} } });
  vm.runInContext(source, context);
  return context;
}
test('empty data and invalid numeric input yield no matches', () => {
  assert.equal(load([]).GetDatas(0, 0, 10).length, 0);
  const finder = load([{ x: 0, y: 0, name: 'Origin' }]);
  for (const values of [[NaN, 0, 1], [0, NaN, 1], [0, 0, NaN], [0, 0, -1]]) {
    assert.equal(finder.GetDatas(...values).length, 0);
  }
});
test('preserves original references, order, and inclusive radius boundary', () => {
  const data = [{ x: 0, y: 0, name: 'Origin' }, { x: 1, y: 0, name: 'Near' }, { x: 30, y: 0, name: 'Far' }];
  const finder = load(data);
  const distance = finder.GetDistance(0, 0, 0, 1);
  const result = finder.GetDatas(0, 0, distance);
  assert.equal(result.length, 2);
  assert.equal(result[0], data[0]); assert.equal(result[1], data[1]);
  assert.equal(finder.GetDatas(0, 0, 0)[0], data[0]);
});
test('matches the original distance formula across coordinate and coercion cases', () => {
  const finder = load([]);
  function original(lat1, lon1, lat2, lon2) {
    const rad = value => value * Math.PI / 180;
    const dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(rad(lat1)) * Math.cos(rad(lat2));
    return 6371 * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
  }
  for (const coordinates of [[37.5, 127, 35.1, 129], [0, 0, 0, 0], [89, 179, -89, -179], ['37', '127', '35', '129'], [null, 0, 0, 0]]) {
    assert.equal(finder.GetDistance(...coordinates), original(...coordinates));
  }
});

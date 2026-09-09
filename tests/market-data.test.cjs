const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

function load(fetch) {
  const source = fs.readFileSync(path.join(__dirname, '../src/sijang-2-manchan/src/datas/data.js'), 'utf8');
  const context = vm.createContext({ fetch });
  vm.runInContext(source.replace('export { Datas, Update };', 'globalThis.subject = { Datas, Update };'), context);
  return context.subject;
}

test('market pagination appends rows in order and accepts an empty page', async () => {
  const pages = [];
  const responses = [[{ name: 'first' }, { name: 'second' }], []];
  const subject = load(async url => {
    pages.push(new URL(url).searchParams.get('page'));
    return { ok: true, json: async () => ({ data: responses.shift() }) };
  });
  let calls = 0;
  await subject.Update(() => calls++);
  await subject.Update(() => calls++);
  assert.deepEqual(Array.from(subject.Datas, row => row.name), ['first', 'second']);
  assert.deepEqual(pages, ['1', '2']);
  assert.equal(calls, 2);
});

test('concurrent load requests append distinct pages in order', async () => {
  const pages = [];
  const subject = load(async url => {
    const page = new URL(url).searchParams.get('page');
    pages.push(page);
    return { ok: true, json: async () => ({ data: [{ page }] }) };
  });
  await Promise.all([subject.Update(() => {}), subject.Update(() => {})]);
  assert.deepEqual(pages, ['1', '2']);
  assert.deepEqual(Array.from(subject.Datas, row => row.page), ['1', '2']);
});

for (const [name, response] of [
  ['network failure', () => { throw new Error('offline'); }],
  ['HTTP failure', () => ({ ok: false, status: 503, json: async () => ({ data: [] }) })],
  ['invalid JSON', () => ({ ok: true, json: async () => { throw new SyntaxError('invalid JSON'); } })],
  ['missing data', () => ({ ok: true, json: async () => ({}) })],
]) {
  test(`${name} keeps the failed page available for retry`, async () => {
    const pages = [];
    const subject = load(async url => {
      pages.push(new URL(url).searchParams.get('page'));
      return pages.length === 1 ? response() : { ok: true, json: async () => ({ data: [{ name: 'retried' }] }) };
    });
    let calls = 0;
    await assert.rejects(subject.Update(() => calls++));
    assert.equal(subject.Datas.length, 0);
    assert.equal(calls, 0);
    await subject.Update(() => calls++);
    assert.deepEqual(pages, ['1', '1']);
    assert.equal(subject.Datas[0].name, 'retried');
    assert.equal(calls, 1);
  });
}

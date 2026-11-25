import assert from 'node:assert/strict';
import test from 'node:test';
import { updatePr } from './update-pr.mjs';

const pr = { number: 1, title: '검색 추가', body: '내가 작성한 설명', changed_files: 0,
  state: 'open', draft: false, head: { sha: 'head', repo: { full_name: 'team/repo' } },
  base: { sha: 'base' }, user: { type: 'User' }, html_url: 'https://github.com/team/repo/pull/1' };
const draft = { changes: ['검색을 추가했습니다.'], verification: [], review: [] };
function client(transform = (value) => value) {
  let reads = 0;
  const writes = [];
  return { writes, request: (endpoint, paginate, payload) => {
    if (payload) { writes.push(payload); return { ...pr, ...payload }; }
    if (paginate) return [[]];
    return transform({ ...pr }, ++reads);
  } };
}

test('생성 중 작성한 최신 본문을 보존하고 본문만 PATCH한다', async () => {
  const api = client((value, reads) => reads >= 4 ? { ...value, body: '생성 중 직접 수정한 설명' } : value);
  const result = await updatePr('team/repo', 1, { ...api, generate: async () => draft, template: '' });
  assert.equal(result.updated, true);
  assert.equal(api.writes.length, 1);
  assert.deepEqual(Object.keys(api.writes[0]), ['body']);
  assert.ok(api.writes[0].body.startsWith('생성 중 직접 수정한 설명'));
});

test('생성 중 코드가 변경되면 이전 요약을 쓰지 않는다', async () => {
  const api = client((value, reads) => reads >= 4 ? { ...value, head: { ...value.head, sha: 'new' } } : value);
  const result = await updatePr('team/repo', 1, { ...api, generate: async () => draft, template: '' });
  assert.equal(result.updated, false);
  assert.equal(api.writes.length, 0);
});

test('게시 직전 본문이 다시 변경되면 저장하지 않는다', async () => {
  const api = client((value, reads) => reads === 5 ? { ...value, body: '추가 수정' } : value);
  const result = await updatePr('team/repo', 1, { ...api, generate: async () => draft, template: '' });
  assert.equal(result.updated, false);
  assert.equal(api.writes.length, 0);
});

test('외부 저장소 PR은 Gemini를 호출하지 않는다', async () => {
  const api = client((value) => ({ ...value, head: { ...value.head, repo: { full_name: 'other/repo' } } }));
  const result = await updatePr('team/repo', 1, { ...api,
    generate: () => assert.fail('호출하면 안 됩니다.'), template: '' });
  assert.equal(result.updated, false);
  assert.equal(api.writes.length, 0);
});

test('Gemini가 실패하면 PR 본문을 저장하지 않는다', async () => {
  const api = client();
  await assert.rejects(updatePr('team/repo', 1, { ...api,
    generate: async () => { throw new Error('HTTP 429'); }, template: '' }), /429/);
  assert.equal(api.writes.length, 0);
});

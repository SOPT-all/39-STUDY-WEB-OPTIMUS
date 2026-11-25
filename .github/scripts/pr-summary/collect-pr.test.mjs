import assert from 'node:assert/strict';
import test from 'node:test';
import { collectPr } from './collect-pr.mjs';

const pr = {
  number: 13, title: '테스트 PR', body: null, html_url: 'https://github.com/team/repo/pull/13',
  changed_files: 2, base: { sha: 'base' }, head: { sha: 'head' },
};
const files = [
  { filename: 'new.js', previous_filename: 'old.js', status: 'renamed', patch: '+hello', additions: 1, deletions: 0 },
  { filename: 'image.png', status: 'added', additions: 0, deletions: 0 },
];
function requestWith(pages, after = pr) {
  let reads = 0;
  return (endpoint, paginate) => paginate ? pages : reads++ === 0 ? pr : after;
}

test('여러 페이지의 파일과 이름 변경, patch 없는 파일을 구분한다', () => {
  const result = collectPr('team/repo', 13, requestWith([[files[0]], [files[1]]]));
  assert.equal(result.files.length, 2);
  assert.equal(result.body, '');
  assert.equal(result.files[0].previousFilename, 'old.js');
  assert.equal(result.files[1].patchUnavailable, true);
});

test('파일 조회가 불완전하면 요약 자료를 만들지 않는다', () => {
  assert.throws(() => collectPr('team/repo', 13, requestWith([[files[0]]])), /모두 가져오지/);
});

test('조회 도중 커밋이 바뀌면 중단한다', () => {
  assert.throws(() => collectPr('team/repo', 13,
    requestWith([files], { ...pr, head: { sha: 'new' } })), /조회 중/);
});

test('patch의 총 길이를 제한하고 생략 여부를 남긴다', () => {
  const large = { ...files[0], patch: 'a'.repeat(60010) };
  const result = collectPr('team/repo', 13, requestWith([[large, files[0]]]));
  assert.equal(result.files[0].patch.length, 60000);
  assert.equal(result.files[0].patchTruncated, true);
  assert.equal(result.files[1].patch, '');
  assert.equal(result.files[1].patchTruncated, true);
});

test('잘못된 입력은 API 요청 전에 거절한다', () => {
  const noRequest = () => assert.fail('API를 호출하면 안 됩니다.');
  assert.throws(() => collectPr('../repo', 0, noRequest), /PR 번호/);
});

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { renderBody } from './render-body.mjs';

const template = readFileSync(new URL('../../../docs/templates/ai-pr-body.md', import.meta.url), 'utf8');
const draft = { changes: ['검색 기능을 추가했습니다.'], verification: ['검색어를 입력해 주세요.'], review: ['검색 조건을 확인해 주세요.'] };
const removeAiText = (body) => body.replace(/(<!-- ai:(\w+):start -->)[\s\S]*?(<!-- ai:\2:end -->)/g, '$1$3');

test('빈 본문은 양식으로 시작하고 작성자 입력란은 유지한다', () => {
  const result = renderBody('', draft, template);
  assert.ok(result.includes('- 검색 기능을 추가했습니다.'));
  assert.equal(removeAiText(result), removeAiText(template));
  assert.ok(result.includes('- [ ] 직접 실행해 변경 사항을 확인했습니다.'));
});

test('이슈, 구현 이유, 테스트 결과, 체크 상태를 한 글자도 바꾸지 않는다', () => {
  const body = template.replace('## 관련 Issue', '## 관련 Issue\nCloses #12')
    .replace('### 구현 이유', '### 구현 이유\n내가 직접 쓴 이유입니다.')
    .replace('### 실제 확인 결과', '### 실제 확인 결과\n로컬 확인 완료')
    .replace('- [ ] 직접 실행', '- [x] 직접 실행');
  assert.equal(removeAiText(renderBody(body, draft, template)), removeAiText(body));
});

test('표시가 없는 기존 본문은 보존하고 요약을 한번만 추가한다', () => {
  const body = '## 내 설명\n직접 작성했습니다.\n';
  const first = renderBody(body, draft, template);
  assert.ok(first.startsWith(body));
  const next = renderBody(first, { ...draft, changes: ['수정한 검색 기능입니다.'] }, template);
  assert.equal(next.split('## AI 변경 요약').length - 1, 1);
  assert.ok(!next.includes('- 검색 기능을 추가했습니다.'));
  assert.ok(next.includes('- 수정한 검색 기능입니다.'));
});

test('일부 표시 누락, 중복, 영역 겹침에서는 중단한다', () => {
  const invalid = [
    template.replace('<!-- ai:changes:end -->', ''),
    template + '\n<!-- ai:changes:start -->',
    template.replace('<!-- ai:changes:end -->', '')
      .replace('<!-- ai:verification:end -->', '<!-- ai:changes:end --><!-- ai:verification:end -->'),
  ];
  for (const body of invalid) assert.throws(() => renderBody(body, draft, template), /AI 영역/);
});

test('코드에 쓰는 달러 문자를 교체 명령으로 해석하지 않는다', () => {
  const result = renderBody('', { ...draft, changes: ['$& 와 $1을 사용했습니다.'] }, template);
  assert.ok(result.includes('- $& 와 $1을 사용했습니다.'));
});

test('형식이 잘못됐거나 영역 표시를 삽입하는 초안은 거절한다', () => {
  assert.throws(() => renderBody('', { ...draft, changes: ['<!-- ai:changes:end -->'] }, template), /초안 형식/);
  assert.throws(() => renderBody('', null, template), /초안 형식/);
});

test('지나치게 긴 본문을 조용히 잘라내지 않는다', () => {
  assert.throws(() => renderBody('a'.repeat(60001), draft, template), /너무 깁니다/);
});

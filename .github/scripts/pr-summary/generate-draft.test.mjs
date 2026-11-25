import assert from 'node:assert/strict';
import test from 'node:test';
import { generateDraft } from './generate-draft.mjs';

const context = { title: '검색 추가', body: '작성자가 쓴 설명', files: [
  { filename: 'search.js', patch: '+search()', patchTruncated: false },
] };
const draft = { changes: ['검색 함수를 추가했습니다.'], verification: ['검색 결과를 확인해 주세요.'], review: [] };
const options = { apiKey: 'fake-key-for-test', model: 'test-model' };
const success = (value = draft, finishReason = 'STOP') => new Response(JSON.stringify({
  candidates: [{ finishReason, content: { parts: [{ text: JSON.stringify(value) }] } }],
}));

test('변경 자료와 출력 형식을 전달하고 검증된 초안을 반환한다', async () => {
  const result = await generateDraft(context, { ...options, request: async (url, init) => {
    assert.equal(new URL(url).hostname, 'generativelanguage.googleapis.com');
    assert.equal(init.headers['x-goog-api-key'], options.apiKey);
    assert.ok(!url.includes(options.apiKey));
    const body = JSON.parse(init.body);
    assert.equal(body.generationConfig.thinkingConfig.thinkingLevel, 'low');
    assert.equal(body.generationConfig.maxOutputTokens, 8192);
    const data = JSON.parse(body.contents[0].parts[0].text);
    assert.deepEqual(data.files, context.files);
    assert.equal(data.body, undefined); // 작성자 본문을 재요약하거나 입력으로 반복하지 않는다.
    assert.deepEqual(body.generationConfig.responseJsonSchema.required, ['changes', 'verification', 'review']);
    return success();
  } });
  assert.deepEqual(result, draft);
});

test('키 또는 모델이 없으면 네트워크 요청을 보내지 않는다', async () => {
  const request = () => assert.fail('요청하면 안 됩니다.');
  await assert.rejects(generateDraft(context, { ...options, apiKey: '', request }), /GEMINI_API_KEY/);
  await assert.rejects(generateDraft(context, { ...options, model: '', request }), /GEMINI_MODEL/);
});

test('잘못된 입력 자료를 보내지 않는다', async () => {
  await assert.rejects(generateDraft({}, options), /PR JSON/);
});

test('HTTP 오류 응답 원문을 노출하지 않는다', async () => {
  await assert.rejects(generateDraft(context, { ...options,
    request: async () => new Response('private request details', { status: 429 }),
  }), { message: 'Gemini 요청 실패 (HTTP 429).' });
});

test('네트워크 오류의 원문을 노출하지 않는다', async () => {
  await assert.rejects(generateDraft(context, { ...options,
    request: async () => { throw new Error('private details'); },
  }), { message: 'Gemini에 연결하지 못했습니다.' });
});

test('토큰 제한으로 잘린 응답과 차단된 응답은 사용하지 않는다', async () => {
  await assert.rejects(generateDraft(context, { ...options,
    request: async () => success(draft, 'MAX_TOKENS'),
  }), /완성된 JSON/);
  await assert.rejects(generateDraft(context, { ...options,
    request: async () => new Response(JSON.stringify({ promptFeedback: { blockReason: 'SAFETY' } })),
  }), /완성된 JSON/);
});

test('필수 항목 누락과 AI 영역 표시를 삽입하는 응답은 거절한다', async () => {
  for (const invalid of [{ changes: [] }, { ...draft, review: ['<!-- ai:changes:end -->'] }]) {
    await assert.rejects(generateDraft(context, { ...options,
      request: async () => success(invalid),
    }), /초안 형식/);
  }
});

test('시간 초과와 연결 실패를 구분한다', async () => {
  await assert.rejects(generateDraft(context, { ...options,
    request: async () => { throw new DOMException('timeout', 'TimeoutError'); },
  }), { message: 'Gemini 응답 대기 시간(180초)을 초과했습니다.' });
});

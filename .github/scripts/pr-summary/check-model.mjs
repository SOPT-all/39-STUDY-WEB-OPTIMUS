// 생성 요청 전에 키로 지정 모델을 조회할 수 있는지 확인합니다.
const key = process.env.GEMINI_API_KEY;
const model = process.env.GEMINI_MODEL;
try {
  if (!key || !model || !/^[A-Za-z0-9._-]+$/.test(model)) {
    throw new Error('GEMINI_API_KEY와 GEMINI_MODEL 설정을 확인해 주세요.');
  }
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}`,
    { headers: { 'x-goog-api-key': key }, signal: AbortSignal.timeout(15000) },
  );
  if (!response.ok) throw new Error(`Gemini 모델 조회 실패 (HTTP ${response.status}).`);
  const data = await response.json();
  if (!data.supportedGenerationMethods?.includes('generateContent')) {
    throw new Error('지정 모델이 generateContent를 지원하지 않습니다.');
  }
  console.log(`Gemini 모델 조회 성공: ${data.name}`);
} catch (error) {
  console.error(error.name === 'TimeoutError' ? 'Gemini 모델 조회 시간 초과(15초).' :
    error instanceof TypeError ? 'Gemini 모델 조회 연결 실패.' : error.message);
  process.exitCode = 1;
}

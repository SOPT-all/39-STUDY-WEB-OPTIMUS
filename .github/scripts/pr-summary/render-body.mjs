import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const sections = [
  ['changes', '변경 내용'],
  ['verification', '확인할 절차 (실행 결과 아님)'],
  ['review', '리뷰 요청'],
];
const marker = (field, edge) => `<!-- ai:${field}:${edge} -->`;

export function renderBody(body, draft, template) {
  if (typeof body !== 'string' || typeof template !== 'string') {
    throw new Error('기존 본문과 PR 양식이 필요합니다.');
  }
  for (const [field] of sections) {
    const items = draft?.[field];
    if (!Array.isArray(items) || items.length > 8 || items.some((item) =>
      typeof item !== 'string' || !item.trim() || item.length > 2000 ||
      /[\r\n]|<!--|-->/.test(item))) {
      throw new Error('PR 초안 형식을 확인해 주세요.');
    }
  }

  let source = body.trim() ? body : template;
  const hasMarker = sections.some(([field]) =>
    source.includes(marker(field, 'start')) || source.includes(marker(field, 'end')));

  // 기존 설명에 표시가 없다면 본문을 재구성하지 않고 요약 영역만 덧붙입니다.
  if (!hasMarker) {
    const block = sections.map(([field, title]) =>
      `### ${title}\n\n${marker(field, 'start')}\n${marker(field, 'end')}`,
    ).join('\n\n');
    source += `\n\n## AI 변경 요약\n\n${block}\n`;
  }

  const ranges = sections.map(([field]) => {
    const start = marker(field, 'start');
    const end = marker(field, 'end');
    const from = source.indexOf(start);
    const to = source.indexOf(end);
    if (from < 0 || to < from + start.length ||
        source.indexOf(start, from + start.length) !== -1 ||
        source.indexOf(end, to + end.length) !== -1) {
      throw new Error('AI 영역 표시가 빠졌거나 중복됐습니다. 본문을 변경하지 않습니다.');
    }
    const text = draft[field].length
      ? draft[field].map((item) => `- ${item.trim()}`).join('\n')
      : '추가로 제안할 내용이 없습니다.';
    return { from: from + start.length, to, text };
  }).sort((a, b) => a.from - b.from);

  for (let i = 1; i < ranges.length; i++) {
    if (ranges[i].from < ranges[i - 1].to) {
      throw new Error('AI 영역이 겹쳐 있습니다. 본문을 변경하지 않습니다.');
    }
  }
  // 뒤에서부터 교체해야 앞쪽 위치가 바뀌지 않습니다.
  let result = source;
  for (const { from, to, text } of ranges.reverse()) {
    result = result.slice(0, from) + `\n${text}\n` + result.slice(to);
  }
  if (result.length > 60000) {
    throw new Error('PR 본문이 너무 깁니다. 기존 내용을 줄인 뒤 다시 실행해 주세요.');
  }
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [contextPath, draftPath] = process.argv.slice(2);
    if (!contextPath || !draftPath) throw new Error('PR JSON과 초안 JSON 경로를 입력해 주세요.');
    let context, draft;
    try {
      context = JSON.parse(await readFile(contextPath, 'utf8'));
      draft = JSON.parse(await readFile(draftPath, 'utf8'));
    } catch {
      throw new Error('입력 JSON 파일을 읽지 못했습니다.');
    }
    const template = await readFile(new URL('../../../docs/templates/ai-pr-body.md', import.meta.url), 'utf8');
    process.stdout.write(renderBody(context.body ?? '', draft, template));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

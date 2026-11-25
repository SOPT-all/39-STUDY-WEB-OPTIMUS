import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { collectPr } from './collect-pr.mjs';
import { generateDraft } from './generate-draft.mjs';
import { renderBody } from './render-body.mjs';

// GitHub에는 GET만 요청합니다. 실제 PR을 수정하지 않는 최초 도입 검증용입니다.
try {
  const [repository, number, outputDirectory] = process.argv.slice(2);
  if (!outputDirectory) throw new Error('저장소, PR 번호, 결과 폴더가 필요합니다.');
  const context = collectPr(repository, number);
  const draft = await generateDraft(context);
  const template = await readFile(new URL('../../../docs/templates/ai-pr-body.md', import.meta.url), 'utf8');
  const body = renderBody(context.body, draft, template);
  const secondBody = renderBody(body, draft, template);
  if (body !== secondBody) throw new Error('반복 실행 시 본문이 중복됩니다.');

  const stripAi = (text) => text.replace(
    /(<!-- ai:(changes|verification|review):start -->)[\s\S]*?(<!-- ai:\2:end -->)/g,
    '$1$3',
  );
  const hasAi = /<!-- ai:(changes|verification|review):start -->/.test(context.body);
  const preserved = !context.body.trim() || (hasAi
    ? stripAi(body) === stripAi(context.body)
    : body.startsWith(context.body));
  if (!preserved) throw new Error('작성자 본문 보존을 확인하지 못했습니다.');

  await mkdir(outputDirectory, { recursive: true });
  await writeFile(join(outputDirectory, 'pr-body.md'), body);
  await writeFile(join(outputDirectory, 'draft.json'), JSON.stringify(draft, null, 2));
  const result = {
    repository, number: context.number, headSha: context.headSha,
    model: process.env.GEMINI_MODEL, files: context.files.length,
    generated: true, authorBodyPreserved: preserved, repeatStable: body === secondBody,
    published: false,
  };
  await writeFile(join(outputDirectory, 'verification.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { collectPr } from './collect-pr.mjs';
import { generateDraft } from './generate-draft.mjs';
import { renderBody } from './render-body.mjs';

export async function updatePr(repository, number, {
  request = githubApi,
  generate = generateDraft,
  template,
} = {}) {
  // 입력 검증과 조회는 기존 수집 함수를 재사용합니다.
  const context = collectPr(repository, number, request);
  const endpoint = `repos/${repository}/pulls/${number}`;
  const initial = request(endpoint);
  const eligible = (pr) => pr.state === 'open' && !pr.draft &&
    pr.head.repo?.full_name === repository && pr.user?.type !== 'Bot';
  if (!eligible(initial)) return { updated: false, reason: '닫힌 PR, 초안, 외부 저장소 또는 봇 PR은 건너뜁니다.' };

  const draft = await generate(context);
  // AI가 응답하는 동안 작성자가 본문을 수정했을 수 있어 최신 본문을 다시 읽습니다.
  const current = request(endpoint);
  const matchesCode = (pr) => pr.head.sha === context.headSha && pr.base.sha === context.baseSha;
  if (!eligible(current) || !matchesCode(current)) {
    return { updated: false, reason: '생성 중 PR 상태나 코드가 바뀌어 게시하지 않았습니다.' };
  }
  const body = renderBody(current.body ?? '', draft, template);
  if (body === (current.body ?? '')) return { updated: false, reason: '기존 요약과 동일합니다.' };

  const latest = request(endpoint);
  if (!eligible(latest) || !matchesCode(latest) || latest.body !== current.body) {
    return { updated: false, reason: '게시 직전 PR이 변경되어 게시하지 않았습니다.' };
  }
  const saved = request(endpoint, false, { body });
  if (saved.body !== body) throw new Error('PR 본문 저장 결과를 확인하지 못했습니다.');
  return { updated: true, url: saved.html_url };
}

function githubApi(endpoint, paginate = false, payload) {
  const args = ['api', '--method', payload ? 'PATCH' : 'GET', endpoint];
  if (paginate) args.push('--paginate', '--slurp');
  if (payload) args.push('--input', '-');
  try {
    return JSON.parse(execFileSync('gh', args, {
      encoding: 'utf8', timeout: 60000, maxBuffer: 32 * 1024 * 1024,
      input: payload ? JSON.stringify(payload) : undefined,
      stdio: ['pipe', 'pipe', 'pipe'],
    }));
  } catch {
    throw new Error('GitHub API 요청에 실패했습니다. 접근 권한과 실행 로그를 확인해 주세요.');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [repository, number] = process.argv.slice(2);
    const template = await readFile(new URL('../../../docs/templates/ai-pr-body.md', import.meta.url), 'utf8');
    const result = await updatePr(repository, number, { template });
    console.log(result.updated ? `PR 요약을 갱신했습니다: ${result.url}` : result.reason);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

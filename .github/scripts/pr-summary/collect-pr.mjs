import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

// API 조회만 수행합니다. PR 본문이나 댓글은 변경하지 않습니다.
export function collectPr(repository, number, request = githubApi) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository) ||
      !/^[1-9]\d*$/.test(String(number))) {
    throw new Error('저장소(owner/repo)와 양의 정수 PR 번호가 필요합니다.');
  }

  const endpoint = `repos/${repository}/pulls/${number}`;
  const before = request(endpoint);
  const pages = request(`${endpoint}/files?per_page=100`, true);
  const files = pages.flat();
  const after = request(endpoint);

  // 조회 도중 코드가 추가되면 서로 다른 시점의 자료가 섞일 수 있습니다.
  if (before.head.sha !== after.head.sha || before.base.sha !== after.base.sha ||
      before.changed_files !== after.changed_files) {
    throw new Error('조회 중 PR이 변경되었습니다. 다시 실행해 주세요.');
  }
  if (files.length !== after.changed_files) {
    throw new Error('변경 파일을 모두 가져오지 못했습니다. 요약을 중단합니다.');
  }

  let remaining = 60000;
  return {
    repository,
    number: after.number,
    title: after.title,
    body: after.body ?? '',
    url: after.html_url,
    baseSha: after.base.sha,
    headSha: after.head.sha,
    files: files.map((file) => {
      const patch = file.patch ?? '';
      const included = patch.slice(0, remaining);
      remaining -= included.length;
      return {
        filename: file.filename,
        previousFilename: file.previous_filename ?? null,
        status: file.status,
        additions: file.additions,
        deletions: file.deletions,
        patch: included,
        patchUnavailable: file.patch == null,
        patchTruncated: included.length < patch.length,
      };
    }),
  };
}

function githubApi(endpoint, paginate = false) {
  const args = ['api', '--method', 'GET', endpoint];
  if (paginate) args.push('--paginate', '--slurp');
  return JSON.parse(execFileSync('gh', args, {
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    timeout: 60000,
    stdio: ['ignore', 'pipe', 'pipe'],
  }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [repository, number] = process.argv.slice(2);
    process.stdout.write(`${JSON.stringify(collectPr(repository, number), null, 2)}\n`);
  } catch (error) {
    // API 오류의 원문 대신 요약된 오류만 출력합니다.
    console.error(error.status != null
      ? 'GitHub 조회에 실패했습니다. gh 인증과 PR 접근 권한을 확인해 주세요.'
      : error.message);
    process.exitCode = 1;
  }
}

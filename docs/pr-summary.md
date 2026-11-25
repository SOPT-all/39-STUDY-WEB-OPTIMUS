# AI 기반 PR 설명 자동화

PR을 올릴 때마다 변경한 파일을 다시 읽으며 설명을 적는 일을 줄여보고 싶었습니다.
GitHub에서 변경 코드를 가져오고, Gemini가 초안을 만든 뒤 PR 본문의 AI 영역에 넣도록 구성했습니다.
구현 이유나 실제 테스트 결과는 코드만으로 알 수 없어서 작성자가 직접 적도록 남겼습니다.

## 실행 순서

1. `test` 또는 `main`으로 PR을 올리거나 새 커밋을 추가합니다.
2. GitHub Actions가 Node.js 22 환경을 준비합니다.
3. `collect-pr.mjs`가 PR 제목, 변경 파일과 코드 차이를 가져옵니다.
4. `generate-draft.mjs`가 Gemini에 자료를 보내 세 항목의 초안을 받습니다.
5. `render-body.mjs`가 최신 본문의 AI 영역만 교체합니다.
6. `update-pr.mjs`가 PR 상태와 코드가 그대로인지 확인하고 본문을 저장합니다.

초안 PR, 외부 저장소에서 올린 PR, 봇이 만든 PR은 건너뜁니다.
본문 수정 이벤트는 실행 조건에서 제외해서 자동화가 자기 수정으로 반복 실행되지 않도록 했습니다.

## 준비할 설정

저장소의 **Settings → Secrets and variables → Actions**에서 설정합니다.

| 종류 | 이름 | 값 |
|---|---|---|
| Secret | `GEMINI_API_KEY` | Google AI Studio에서 발급한 키 |
| Variable | `GEMINI_MODEL` | `gemini-3.8-flash` |

키와 모델 이름은 별개입니다. 키는 요청 인증에 사용하고, 모델 이름은 어느 모델에 요청할지 정합니다.
API 키는 파일이나 PR 본문에 적지 않습니다. `GITHUB_TOKEN`은 실행할 때 GitHub가 제공합니다.
모델의 사용 가능 여부와 한도는 실제 요청으로 확인해야 합니다.

## 머지 전 실제 Gemini 호출 확인

`AI PR Summary Preview`는 `auto/pr-summary-minsik` 브랜치에서 자동화 코드가 바뀌면 실행됩니다.
현재 도입 PR #22의 변경 내용을 Gemini에 보내고, 결과를 Actions의 `pr-summary-preview` 파일로 남깁니다.
다운로드한 `pr-body.md`에서 본문을, `verification.json`에서 원문 보존과 반복 실행 결과를 확인할 수 있습니다.
GitHub 토큰은 읽기 권한만 사용하며, Draft 해제·PR 본문 수정·머지는 하지 않습니다.
이 실행은 Gemini 호출과 본문 생성을 검증합니다. GitHub에 본문을 저장하는 동작은 별도 검증이 필요합니다.
최초 검증을 위한 전용 경로이므로 다른 작업 브랜치나 외부 PR에서는 실행되지 않습니다.

## 최초 적용과 실제 PR 반영 검증

자동화는 PR에서 바뀐 스크립트 대신 대상 브랜치의 스크립트를 실행합니다.
따라서 처음 기능을 추가하는 PR은 대상 브랜치에 코드가 없어 안내 메시지만 남기고 건너뜁니다.

1. 작업 브랜치를 푸시하고 `test`로 도입 PR을 올립니다.
2. 검토 후 `test`에 반영합니다.
3. `test`를 기준으로 작은 변경을 만든 후속 PR을 올립니다.
4. Actions의 **AI PR Summary** 실행 결과와 PR 본문을 확인합니다.
5. 작성자 영역에 문장을 적고 체크박스를 체크한 뒤, 새 커밋을 추가합니다.
6. AI 영역이 갱신되고 직접 적은 문장과 체크 상태는 유지되는지 확인합니다.
7. 실제 검증 결과를 정리한 뒤 `test → main` 제출 PR을 올립니다.

기능 도입 PR이 건너뛰어진 것만으로 Gemini 호출까지 성공했다고 판단하지 않습니다.

## 본문에서 바뀌는 부분

- **변경 내용**: 코드에서 확인되는 변경 사항입니다.
- **확인할 절차**: 리뷰어에게 제안하는 확인 방법입니다. 실행 완료 결과가 아닙니다.
- **리뷰 요청**: 변경 코드와 연결되는 검토 지점입니다.

본문이 비어 있으면 `docs/templates/ai-pr-body.md`를 사용합니다.
기존 본문에 AI 표시가 없다면 원래 내용을 보존하고 아래에 **AI 변경 요약**을 추가합니다.
다음 실행부터는 `<!-- ai:changes:start -->` 같은 표시 사이만 갱신합니다.
AI 영역 안에서 직접 수정한 문장은 다음 실행 때 교체됩니다. 남겨야 할 내용은 작성자 영역에 적습니다.
표시가 일부 빠졌거나 중복되면 잘못 덮어쓰지 않도록 중단합니다.

## 로컬에서 확인하기

GitHub CLI 인증과 Node.js 22가 필요합니다. 별도로 설치할 npm 패키지는 없습니다.
저장소 루트에서 실행합니다.

```bash
node --test .github/scripts/pr-summary/*.test.mjs
```

변경 자료만 확인할 때는 다음 명령을 사용합니다. PR은 변경하지 않습니다.

```bash
node .github/scripts/pr-summary/collect-pr.mjs SOPT-all/39-STUDY-WEB-OPTIMUS 13 > /tmp/optimus-pr-context.json
```

`GEMINI_API_KEY`와 `GEMINI_MODEL`이 로컬 환경변수에 준비돼 있다면 초안을 만들 수 있습니다.
GitHub Secret은 로컬 환경변수로 자동 전달되지 않습니다.

```bash
node .github/scripts/pr-summary/generate-draft.mjs /tmp/optimus-pr-context.json > /tmp/optimus-pr-draft.json
node .github/scripts/pr-summary/render-body.mjs /tmp/optimus-pr-context.json /tmp/optimus-pr-draft.json > /tmp/optimus-pr-body.md
```

위 두 명령도 파일만 생성합니다. `update-pr.mjs`는 실제 PR을 수정하므로 확인용 PR에서만 실행합니다.

## 현재 확인한 범위

- 로컬 테스트 24개가 통과했습니다. AI 응답과 PR 저장은 모의 응답으로 확인했습니다.
- 기존 PR #13의 변경 파일 10개와 코드 차이를 실제 GitHub API로 가져왔습니다.
- Node.js 구문과 워크플로 YAML 구문을 확인했습니다.
- **실제 Gemini 응답과 Actions의 PR 본문 갱신은 아직 확인하지 않았습니다.**

실제 실행 후에는 위 상태를 결과 링크와 함께 갱신할 예정입니다.

## 실행이 실패했을 때

| 상황 | 확인할 것 |
|---|---|
| `GEMINI_API_KEY가 필요합니다` | Secret 이름과 값 등록 여부 |
| `GEMINI_MODEL` 오류 | Variables에 모델 이름이 등록됐는지 |
| HTTP 400 또는 404 | 모델 이름, 요청 형식, 키와 모델의 지원 범위 |
| HTTP 401 또는 403 | 키 인증 상태와 프로젝트 접근 권한 |
| HTTP 429 | API 사용 한도와 요청 빈도 |
| GitHub API 요청 실패 | Actions의 PR 쓰기 권한과 조직 정책 |
| AI 영역 표시 오류 | 시작·끝 표시가 삭제되거나 중복됐는지 |

실패한 경우에는 기존 PR 본문을 대체하는 안내 문구를 쓰지 않고 실행을 중단합니다.

## 한계

코드 차이가 없는 파일은 내용까지 분석할 수 없습니다.
전달하는 코드 차이는 총 60,000자로 제한하며 생략 여부를 AI에 전달합니다.
AI가 제안한 확인 절차와 실제 테스트 결과는 다르므로, 작성자가 초안을 검토해야 합니다.
생성 중 코드가 바뀌면 게시하지 않고, 저장 직전에도 본문을 재조회합니다.
다만 마지막 조회와 저장은 별개의 요청이므로 그 짧은 사이의 동시 수정까지 막는 것은 아닙니다.

## 참고

- [Gemini 콘텐츠 생성 API](https://ai.google.dev/api/generate-content)
- [Gemini 3.8 Flash 모델 안내](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash)
- [GitHub CLI API 요청](https://cli.github.com/manual/gh_api)
- [GitHub Actions PR 이벤트](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)

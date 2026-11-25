# 실제 PR 이벤트 검증

2026년 11월 25일, [테스트 PR #24](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/pull/24)에서 정규 `AI PR Summary` 워크플로를 확인했습니다.

## 검증 방법

테스트 브랜치에서만 워크플로 대상에 `auto/pr-summary-minsik`을 추가했습니다.
도입 PR의 운영 설정은 `test`, `main` 그대로 유지했습니다.
나머지 조건, 대상 브랜치 코드 체크아웃, Gemini 호출, PR 저장 코드는 운영 경로와 같습니다.

- [PR 생성 이벤트](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/actions/runs/45529137907): Gemini 초안이 실제 본문에 저장됐습니다.
- [첫 새 커밋 이벤트](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/actions/runs/45529256082): 저장과 작성자 영역 보존이 성공했습니다. 다만 새 로직에 대한 설명이 추상적이었습니다.
- [최신 지침을 적용한 새 커밋 이벤트](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/actions/runs/45529616329): 아래와 같이 구체적인 동작을 설명하는 요약으로 갱신됐습니다.

## 마지막 실행의 실제 변경 요약

- .github/workflows/pr-summary.yml 파일의 pull_request 트리거 브랜치 목록에 auto/pr-summary-minsik 브랜치를 추가했습니다
- verification/event-demo.js 파일에 문자열의 앞뒤 공백을 제거하고 연속된 공백을 단일 공백으로 치환한 뒤 소문자로 변환하는 formatName 함수를 추가했습니다

## 확인 결과

- 실제 이벤트 종류가 `pull_request`인 것을 확인했습니다.
- `opened`와 `synchronize`에서 본문 생성·갱신에 성공했습니다.
- AI 영역을 제외한 본문 전체가 실행 직전과 동일했습니다.
- 작성자 메모 두 개와 체크 상태가 유지됐고, AI 영역이 중복 추가되지 않았습니다.
- 로그에서 최신 지침 커밋 `3e7a9e2`를 실제로 체크아웃한 것을 확인했습니다.
- 테스트 PR은 확인 후 머지 없이 닫았습니다. 도입 PR #22는 Draft입니다.
- `test`와 `main`의 커밋은 검증 전후 동일했습니다.

## 검증 중 보완한 점

초안이 "문자열 포맷팅"처럼 구체적인 연산을 생략해, 함수 이름과 입력 처리·반환 동작을 명시하도록 지침을 보완했습니다.
PR 재개 이벤트에서는 이전 대상 커밋이 선택된 실행도 있었으므로, 실제 체크아웃 SHA를 확인하고 새 커밋 이벤트로 다시 검증했습니다.
AI 문장에는 편차가 있을 수 있어 작성자의 검토는 여전히 필요합니다.

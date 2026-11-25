# CI 자동 검증

## 목적

GitHub Actions 워크플로와 셸 스크립트의 오류를
머지 전에 발견하고, 변경 파일에 따라 필요한 검사만 실행한다.

## 구성

- actionlint 1.7.12: GitHub Actions 워크플로 검사
- ShellCheck 0.11.0: 셸 스크립트와 커밋 훅 검사
- dorny/paths-filter v4: 변경 파일 분류

설정 파일: `.github/workflows/ci.yml`

## 실행 조건

- `auto/ci-pr-validation-yumin` 브랜치에 push
- `test` 또는 `main`을 대상으로 PR 생성·업데이트

## 검사 선택 기준

| 변경 파일                                      | 실행할 검사   |
| ---------------------------------------------- | ------------- |
| `.github/workflows/` 내부 파일                 | Workflow 검사 |
| `.github/scripts/*.sh`, `.githooks/` 내부 파일 | Shell 검사    |
| `.github/workflows/ci.yml`                     | 두 검사 모두  |
| 문서만 변경                                    | 두 검사 생략  |

선택된 검사는 해당 종류의 파일 전체를 검사한다.

## 검증 기록

### 1. 정상 코드 검사

- 방법: CI 설정을 추가하고 작업 브랜치에 push한 뒤 PR을 생성했다.
- 예상: Workflow 검사와 Shell 검사가 통과한다.
- 결과: push와 PR 실행에서 두 검사 모두 통과했다.

### 2. 오류 감지

- 방법: `.github/scripts/ci-failure-demo.sh`에 아래 코드를 추가했다.

  #!/usr/bin/env bash
  message="CI failure demo"
  echo $message

- 예상: 큰따옴표가 빠진 변수 사용을 ShellCheck가 감지한다.
- 결과: 3번째 줄에서 SC2086을 감지하고 Shell 검사가 실패했다.

### 3. 정상 복구

- 방법: 오류 감지용 스크립트를 삭제하고 push했다.
- 예상: Shell 검사가 다시 통과한다.
- 결과: 전체 검사가 통과했다.

### 4. CI 설정 변경 시 검사 선택

- 방법: 변경 파일 분류 기능을 `ci.yml`에 추가하고 push했다.
- 예상: 변경 파일 확인 후 두 검사를 모두 실행한다.
- 결과: 변경 파일 확인과 두 검사 모두 통과했다.

### 5. 문서만 변경할 때 검사 생략

- 방법: 이 문서만 변경한 커밋을 push한다.
- 예상:
  - push 실행: 변경 파일 확인은 통과하고 두 검사는 Skipped로 표시된다.
  - PR 실행: PR 전체에 `ci.yml` 변경이 있으므로 두 검사를 실행한다.
- 결과: 확인 예정.

## push와 PR의 비교 범위

- push: push 직전 커밋과 비교한 변경분을 사용한다.
- PR: 대상 브랜치와 비교한 PR 전체 변경분을 사용한다.

따라서 같은 커밋에서도 push와 PR의 검사 선택 결과가 다를 수 있다.

## 남은 작업

- 문서 변경 시 검사 생략 결과 기록
- 검증 실행 링크와 스크린샷 추가
- 동작 테스트와 결과 리포트 추가
- 필수 상태 검사 및 배포 자동화 구성

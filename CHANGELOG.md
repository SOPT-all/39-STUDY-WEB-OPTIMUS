# Changelog

## 1.0.0 (2026-11-11)


### ✨ 새로운 기능

* PR 이벤트 디스코드 알림 워크플로우 추가 ([6493fee](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/6493feed0d9a4b66307a0fc80baf754f168456d4))
* release-please 릴리즈 자동화 및 디스코드 릴리즈 알림 추가 ([ac6b311](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/ac6b311ea0b152aed4aa2f53311a467cb5aafb2a))
* 닫힌 PR 스레드 보관 및 기존 스레드 백필 워크플로우 추가 ([40fc068](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/40fc0685e2fb420e9bd8cc4ffda2071b138d8ade))
* 디스코드 embed 메시지 생성 및 유저 멘션 매핑 추가 ([e045060](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/e04506056a6ac27b9b547e24a3b1f6ec41129cc3))
* 디스코드 웹훅 전송 및 rate limit 재시도 추가 ([48934d3](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/48934d383739d41cb457ab2124a178bdf93f66dd))
* 리뷰 대기 PR 에 다른 리뷰어의 변경 요청도 함께 표시 ([f6672ef](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f6672efcfd396ea0d12a6a53231a048b4434d205))
* 리뷰 상태 기반 PR 분류 로직 추가 ([95b0ebd](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/95b0ebd193a7d3cea954bc4efb3e0fa7725f3471))
* 열린 PR 조회 및 draft/라벨/제목/경과시간 필터 추가 ([fa60b7c](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/fa60b7c39bdff2530b1c168268b7f7e87c1dfa18))
* 워크플로 실패 시 디스코드 알림 추가 ([3048ba4](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/3048ba4dd5920e25d65b0a14313dc5fde470b839))
* 커밋 컨벤션 검사 워크플로우 및 commit-msg 훅 추가 ([ec443d2](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/ec443d231c0910716e08e2309374d4cde3ad5334))


### 🐛 버그 수정

* env BOT_NAME 값을 변경해 봇 표시 이름이 반영되도록 수정 ([e39d93b](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/e39d93b80045c15e37c10ff3cd9ae1bdc6700d13))
* PR [#11](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/issues/11) 코드리뷰 반영 ([c6f505a](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/c6f505afc6149fee748d95497afc49f39a8d6bdf))
* 디스코드 메시지에서 PR 제목 이스케이프 문자가 노출되는 문제 수정 ([e244994](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/e24499407418151f0ff794c1ad50b766847e5dfe))
* 리뷰 재요청 시 스레드 멘션 누락 수정 ([f0574a1](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f0574a1ede11d08a42f1406e9bbce28c4bf5e628))
* 릴리즈 PR 생성에 개인 토큰 사용 ([f4ffff9](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f4ffff90f9f3417ff6f2cba707937924fe774cd1))
* 메타데이터 저장 실패 후 재실행 시 디스코드 카드 중복 생성 방지 ([a2e3cb3](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/a2e3cb31e15aacced05f41348aa9684026df811a))
* 커밋 컨벤션 검사를 base 브랜치 규칙으로 실행하고 조회 실패 시 실패 처리 ([1147e0c](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/1147e0c5ea02b7923f00ef7b66599bd492be9ac3))


### ♻️ 리팩토링

* 스레드 멤버 추가를 작성자·리뷰어로 한정 ([c67531f](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/c67531fe127987fa4230d513f2761b42e952cab0))


### 📝 문서

* add README and PR template ([9926475](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/99264756beabf22d68506bcb847cbbe459460b33))
* 디스코드 PR 봇 발표 자료 추가 ([be711aa](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/be711aa3de2ef8a44aecba4846cba8f2b7f28322))
* 디스코드 PR 봇 설정 가이드 추가 ([28eadeb](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/28eadeb3f272ef3338f15f0c8dd135f70eb739de))
* 리뷰 재요청 알림 문서 및 발표 자료 반영 ([f867575](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f867575a400ea142def3975f924c5f09bcef4ae8))
* 릴리즈 PR 과 리마인드 봇 연동 주의사항 추가 ([93fbb14](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/93fbb14871a0d61071d99d72615db76cea67b331))
* 릴리즈 알림 워크플로우 주석 실제 동작에 맞게 수정 ([2597280](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/25972803607f312f54db23db1d5fdd08e27f6c91))
* 발표 자료 트러블슈팅 내용 최신화 ([400e47b](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/400e47bc7c8171661d790204726031e8325a299e))
* 스레드 보관 동작 문서 및 발표 자료 반영 ([75fc1aa](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/75fc1aa6ac66ebacaa8ecb26f5f364570bfb6446))
* 중간 실패 복구 동작 문서 및 발표 자료 반영 ([f22f816](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f22f816eab7a39ce4f599b1fd84feb5ed993a43e))
* 커밋 컨벤션 및 릴리즈 가이드 추가 ([f85e7cd](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/f85e7cd6ffede1aff59f20077b6f97f5e189da7e))
* 커밋 컨벤션 및 릴리즈 발표 자료 추가 ([263af10](https://github.com/SOPT-all/39-STUDY-WEB-OPTIMUS/commit/263af10fd0d4547287e7b05a8cd20696f853f5f0))

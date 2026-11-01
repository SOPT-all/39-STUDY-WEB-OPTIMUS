# 🔔 Discord PR Bot

PR 이벤트를 디스코드 채널로 알리고, PR마다 스레드를 만들어 진행 상황을 모아 보여주는 자동화예요.

---

### 📌 이벤트별 동작

| 이벤트                                      | 디스코드 동작                                             |
| :------------------------------------------ | :-------------------------------------------------------- |
| `opened` / `reopened` / `ready_for_review`  | 채널에 PR 카드 + 스레드 생성 (draft PR 제외)              |
| `review_requested` / `review_request_removed` | 스레드에 리뷰어 멘션                                    |
| `synchronize`                               | 스레드에 새 커밋 알림                                     |
| `edited`                                    | PR 카드 내용 갱신                                         |
| `closed`                                    | PR 카드에 머지 완료 / 머지 없이 종료 표시 + 스레드 알림   |

---

### 📌 다른 레포에 적용하기

#### 1. 디스코드 봇 만들기

1. [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
2. **Bot** 탭 → **Reset Token** 으로 토큰 복사
3. 아래 링크의 `APP_ID` 를 Application ID 로 바꿔 서버에 초대

```
https://discord.com/oauth2/authorize?client_id=APP_ID&scope=bot&permissions=309237730304
```

> 채널 보기 · 메시지 보내기 · 링크 첨부 · 메시지 기록 보기 · 공개 스레드 만들기 · 스레드에서 메시지 보내기 권한이 포함돼 있어요.

#### 2. 파일 복사

- `.github/workflows/discord-pr-bot.yml`
- `.github/scripts/discord-pr-bot.sh`

#### 3. Repository Secrets 등록

| Secret                  | 값                                                     |
| :---------------------- | :----------------------------------------------------- |
| `DISCORD_BOT_TOKEN`     | 봇 토큰                                                |
| `DISCORD_PR_CHANNEL_ID` | 알림 받을 채널 id                                      |
| `DISCORD_USER_MAP`      | `{"github아이디":"디스코드id"}` 형식의 JSON (멘션용)   |

> 디스코드 id 는 설정 → 고급 → **개발자 모드** 를 켠 뒤 우클릭 → **ID 복사** 로 얻을 수 있어요.

---

### 📌 참고

- PR 에 달리는 `🤖 Discord 알림 연동용 댓글` 은 메시지/스레드 id 를 저장하는 용도라 삭제하면 연동이 끊겨요.
- PR 카드의 **작업 요약** 은 PR 템플릿의 `## 🤖 Summary` 섹션에서 가져와요.
- `DISCORD_USER_MAP` 에 없는 사람은 멘션 대신 `@github아이디` 로 표시돼요.
- 스레드에는 작성자와 처음 지정된 리뷰어만 초대해요. 나중에 지정된 리뷰어는 스레드 멘션으로 자동 참여돼요.

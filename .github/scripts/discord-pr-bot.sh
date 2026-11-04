#!/usr/bin/env bash
# PR 이벤트를 Discord 채널로 알린다.
# - PR 이 열리면 부모 메시지 + 스레드를 만들고, 그 id 를 PR 숨김 댓글에 저장한다.
# - 이후 이벤트는 저장된 id 로 부모 메시지를 갱신하고 스레드에 답글을 남긴다.
# 사용자 입력(제목·본문·브랜치명)은 전부 이벤트 JSON 에서 jq 로 읽어 셸 인젝션을 막는다.
set -euo pipefail

DISCORD_API="https://discord.com/api/v10"
REPO="$GITHUB_REPOSITORY"
REPO_NAME="${REPO#*/}"
[ -n "${DISCORD_USER_MAP:-}" ] || DISCORD_USER_MAP='{}'

event() { jq -r "$1" "$GITHUB_EVENT_PATH"; }

ACTION=$(event '.action')
PR_NUMBER=$(event '.pull_request.number')
PR_TITLE=$(event '.pull_request.title')
PR_URL=$(event '.pull_request.html_url')
PR_BODY=$(event '.pull_request.body // ""' | tr -d '\r')
AUTHOR=$(event '.pull_request.user.login')
HEAD_REF=$(event '.pull_request.head.ref')
BASE_REF=$(event '.pull_request.base.ref')
IS_DRAFT=$(event '.pull_request.draft')
MERGED=$(event '.pull_request.merged')

# ---------- helpers ----------

# Discord REST 호출: discord METHOD PATH [JSON]
discord() {
  local args=(-sS -X "$1" "$DISCORD_API$2" -H "Authorization: Bot $DISCORD_BOT_TOKEN")
  [ $# -ge 3 ] && args+=(-H "Content-Type: application/json" --data "$3")
  curl "${args[@]}"
}

# github 로그인 → Discord 멘션(매핑 없으면 @로그인, 핑 안 감)
mention() {
  local id
  id=$(jq -r --arg l "$1" '.[$l] // empty' <<< "$DISCORD_USER_MAP")
  if [ -n "$id" ]; then echo "<@$id>"; else echo "@$1"; fi
}

# 스레드 이름: "[표시 ]PR #N 제목" (Discord 100자 제한 → 90자)
thread_name() {
  local name
  name=$(printf '%sPR #%s %s' "${1:+$1 }" "$PR_NUMBER" "$PR_TITLE")
  echo "${name:0:90}"
}

# 스레드 이름·보관 상태 변경: update_thread THREAD_ID NAME ARCHIVED(true|false)
# 알림 본체는 이미 나갔으므로 실패해도 경고만 남긴다.
update_thread() {
  local resp
  resp=$(discord PATCH "/channels/$1" "$(jq -n --arg n "$2" --argjson a "$3" '{name: $n, archived: $a, locked: false}')")
  [ -n "$(jq -r '.id // empty' <<< "$resp")" ] || echo "::warning::스레드 상태 변경 실패: $resp"
}

join_lines() { paste -sd ',' - | sed 's/,/, /g'; }

reviewer_text() {
  local logins out=""
  logins=$(event '.pull_request.requested_reviewers[]?.login')
  [ -z "$logins" ] && { echo "없음"; return; }
  while IFS= read -r l; do out+="$(mention "$l")"$'\n'; done <<< "$logins"
  printf '%s' "$out" | join_lines
}

label_text() {
  local labels
  labels=$(event '[.pull_request.labels[]?.name] | join(", ")')
  echo "${labels:-없음}"
}

# 본문의 close/fix/resolve #N → 이슈 상태와 링크
issue_text() {
  local nums out="" state emoji
  nums=$(grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+' <<< "$PR_BODY" | grep -oE '[0-9]+' | sort -un || true)
  [ -z "$nums" ] && { echo "없음"; return; }
  while IFS= read -r n; do
    state=$(gh api "repos/$REPO/issues/$n" --jq '.state' 2>/dev/null || echo unknown)
    case "$state" in open) emoji="🟢" ;; closed) emoji="⚫" ;; *) emoji="❓" ;; esac
    # <> 로 감싸 Discord 링크 미리보기 카드를 막는다
    out+="$emoji [#$n](<https://github.com/$REPO/issues/$n>)"$'\n'
  done <<< "$nums"
  printf '%s' "$out"
}

# PR 템플릿의 "## 🤖 Summary" 섹션 내용을 "• ..." 목록으로(HTML 주석 제외)
summary_text() {
  awk '
    in_c { if ($0 ~ /-->/) in_c = 0; next }
    /<!--/ { if ($0 !~ /-->/) in_c = 1; next }
    /^##[[:space:]]/ { if (in_s) exit; if ($0 ~ /[Ss]ummary|작업 요약/) in_s = 1; next }
    in_s && /^---/ { exit }
    in_s {
      s = $0
      sub(/^[[:space:]]*([-*][[:space:]]+)?/, "", s)
      sub(/[[:space:]]+$/, "", s)
      if (s != "") { out = out (n++ ? "\n" : "") "• " s }
    }
    END { print (n ? out : "요약 없음") }
  ' <<< "$PR_BODY"
}

build_message() {
  local status="$1" text
  text=$(cat <<EOF
[PR] [$REPO_NAME#$PR_NUMBER $PR_TITLE]($PR_URL)
$status

🔥 **연관 이슈**
$(issue_text)

📝 **작업 요약**
$(summary_text)

**Author**: $(mention "$AUTHOR")
**Branch**: \`$HEAD_REF\` → \`$BASE_REF\`
**Reviewer**: $(reviewer_text)
**Label**: $(label_text)
EOF
)
  # Discord content 2000자 제한
  echo "${text:0:1900}"
}

message_json() {
  jq -n --arg c "$1" '{content: $c, allowed_mentions: {parse: ["users"]}}'
}

# ---------- 저장된 Discord 메타데이터 조회 ----------

META=$(gh api --paginate "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login == "github-actions[bot]") | .body' \
  | grep -oP 'discord-pr-bot: \K\{[^}]*\}' | tail -n 1 || true)

# ---------- 최초 알림: 부모 메시지 + 스레드 생성 ----------

if [ -z "$META" ]; then
  case "$ACTION" in opened | reopened | ready_for_review) ;; *)
    echo "No Discord thread for this PR yet; skipping '$ACTION'."; exit 0 ;;
  esac
  if [ "$IS_DRAFT" = "true" ]; then
    echo "Draft PR; waiting for ready_for_review."; exit 0
  fi

  INITIAL_REVIEWERS=$(event '[.pull_request.requested_reviewers[]?.login]' | jq -c .)

  # 이전 실행이 Discord 생성 후 중간에 실패했다면(댓글 저장 실패 등) 채널에 카드가 남아 있다.
  # 새로 만들기 전에 최근 100개 메시지에서 이 PR 링크를 가진 봇 메시지를 찾아 재사용해, 재실행해도 중복이 생기지 않게 한다.
  BOT_ID=$(discord GET "/users/@me" | jq -r '.id // empty')
  MESSAGE_ID=$(discord GET "/channels/$DISCORD_CHANNEL_ID/messages?limit=100" \
    | jq -r --arg b "$BOT_ID" --arg u "]($PR_URL)" \
      '(if type == "array" then . else [] end) | [.[] | select(.author.id == $b and (.content | contains($u)))][0].id // empty')

  if [ -n "$MESSAGE_ID" ]; then
    echo "Reusing Discord message $MESSAGE_ID left by a previous run."
    discord PATCH "/channels/$DISCORD_CHANNEL_ID/messages/$MESSAGE_ID" "$(message_json "$(build_message "")")" > /dev/null
  else
    RESP=$(discord POST "/channels/$DISCORD_CHANNEL_ID/messages" "$(message_json "$(build_message "")")")
    MESSAGE_ID=$(jq -r '.id // empty' <<< "$RESP")
    [ -n "$MESSAGE_ID" ] || { echo "Discord post failed: $RESP"; exit 1; }
  fi

  # 메시지에서 만든 스레드는 id 가 메시지 id 와 같다. 이미 있으면 재사용하고, 없을 때만 만든다.
  THREAD_ID=$(discord GET "/channels/$MESSAGE_ID" | jq -r '.id // empty')
  if [ -z "$THREAD_ID" ]; then
    RESP=$(discord POST "/channels/$DISCORD_CHANNEL_ID/messages/$MESSAGE_ID/threads" \
      "$(jq -n --arg n "$(thread_name)" '{name: $n, auto_archive_duration: 10080}')")
    THREAD_ID=$(jq -r '.id // empty' <<< "$RESP")
    [ -n "$THREAD_ID" ] || { echo "Discord thread create failed: $RESP"; exit 1; }

    # 작성자 + 처음 지정된 리뷰어만 스레드 멤버로 추가해 사이드바에 노출(실패해도 무시).
    # 전원을 추가하면 "스레드에 추가했어요" 시스템 메시지가 인원수만큼 쌓인다.
    # 이후 지정되는 리뷰어는 스레드 멘션으로 자동 참여된다.
    jq -r --arg a "$AUTHOR" --argjson r "$INITIAL_REVIEWERS" \
      '([$a] + $r | unique)[] as $l | .[$l] // empty' <<< "$DISCORD_USER_MAP" | while read -r uid; do
      discord PUT "/channels/$THREAD_ID/thread-members/$uid" > /dev/null || true
    done
  fi

  # 메타데이터 댓글 저장 — 일시적인 오류에 대비해 최대 3번 시도한다.
  # 끝내 실패해도 재실행하면 위에서 기존 카드·스레드를 찾아 이 단계부터 이어간다.
  META=$(jq -nc --arg c "$DISCORD_CHANNEL_ID" --arg m "$MESSAGE_ID" --arg t "$THREAD_ID" \
    --argjson r "$INITIAL_REVIEWERS" '{channel_id: $c, message_id: $m, thread_id: $t, initial_reviewers: $r}')
  BODY=$(printf '%s\n<!-- discord-pr-bot: %s -->' \
    '🤖 Discord 알림 연동용 댓글입니다. 수정·삭제하면 PR 과 Discord 스레드 연동이 끊겨요.' "$META")
  for attempt in 1 2 3; do
    gh api "repos/$REPO/issues/$PR_NUMBER/comments" -f body="$BODY" > /dev/null && break
    if [ "$attempt" -eq 3 ]; then
      echo "Saving metadata comment failed. Re-run this job to resume without duplicating the Discord thread."
      exit 1
    fi
    sleep $((attempt * 2))
  done

  echo "Posted Discord message $MESSAGE_ID with thread $THREAD_ID."
  exit 0
fi

# ---------- 이후 이벤트: 부모 메시지 갱신 + 스레드 답글 ----------

CHANNEL_ID=$(jq -r '.channel_id' <<< "$META")
MESSAGE_ID=$(jq -r '.message_id' <<< "$META")
THREAD_ID=$(jq -r '.thread_id' <<< "$META")

STATUS=""
if [ "$ACTION" = "closed" ]; then
  if [ "$MERGED" = "true" ]; then STATUS="✅ 머지 완료"; else STATUS="🗑️ 머지 없이 종료됨"; fi
fi

RESP=$(discord PATCH "/channels/$CHANNEL_ID/messages/$MESSAGE_ID" "$(message_json "$(build_message "$STATUS")")")
[ -n "$(jq -r '.id // empty' <<< "$RESP")" ] || { echo "Discord update failed: $RESP"; exit 1; }

REPLY=""
case "$ACTION" in
  review_requested)
    REVIEWER=$(event '.requested_reviewer.login // empty')
    # 이미 리뷰를 남긴 사람에게 다시 요청했다면 리뷰 반영 후 재요청이다
    REVIEW_COUNT=$(gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/reviews" \
      | jq -s --arg r "$REVIEWER" '[.[][] | select(.user.login == $r)] | length')
    if [ "$REVIEW_COUNT" -gt 0 ]; then
      REPLY="🔁 리뷰 재요청: $(mention "$REVIEWER")"
    # PR 을 열 때 지정된 리뷰어의 첫 요청은 GitHub 가 opened 와 함께 보내는 이벤트라,
    # 부모 메시지에 이미 표시돼 있으므로 답글을 생략한다
    elif jq -e --arg r "$REVIEWER" '.initial_reviewers | any(.[]; . == $r) | not' <<< "$META" > /dev/null; then
      REPLY="🙋 리뷰 요청: $(mention "${REVIEWER:-unknown}")"
    fi
    ;;
  review_request_removed)
    REVIEWER=$(event '.requested_reviewer.login // empty')
    REPLY="➖ 리뷰 요청 해제: $(mention "${REVIEWER:-unknown}")"
    ;;
  synchronize)
    SHA=$(event '.pull_request.head.sha')
    COMMIT_MSG=$(gh api "repos/$REPO/commits/$SHA" --jq '.commit.message' | head -n 1)
    REPLY="🔨 새 커밋 푸시 (총 $(event '.pull_request.commits')개)"$'\n'"> \`${SHA:0:7}\` $COMMIT_MSG"
    ;;
  closed)
    if [ "$MERGED" = "true" ]; then REPLY="✅ \`$BASE_REF\` 에 머지되었어요!"; else REPLY="🗑️ PR 이 머지 없이 닫혔어요."; fi
    ;;
  reopened) REPLY="🔄 PR 이 다시 열렸어요." ;;
  ready_for_review) REPLY="👀 리뷰 준비 완료!" ;;
esac

# 다시 열리면 보관을 풀고 이름의 ✅/🗑️ 표시를 뗀다(답글보다 먼저)
if [ "$ACTION" = "reopened" ]; then
  update_thread "$THREAD_ID" "$(thread_name)" false
fi

if [ -n "$REPLY" ]; then
  RESP=$(discord POST "/channels/$THREAD_ID/messages" "$(message_json "$REPLY")")
  [ -n "$(jq -r '.id // empty' <<< "$RESP")" ] || { echo "Discord thread reply failed: $RESP"; exit 1; }
fi

# 닫히면 이름에 결과 표시를 붙이고 보관해 사이드바에서 뺀다(답글 다음).
# 잠그지는 않아서 머지 후에도 글을 쓸 수 있고, 글을 쓰면 다시 열린다.
if [ "$ACTION" = "closed" ]; then
  if [ "$MERGED" = "true" ]; then PREFIX="✅"; else PREFIX="🗑️"; fi
  update_thread "$THREAD_ID" "$(thread_name "$PREFIX")" true
fi

echo "Handled '$ACTION' for PR #$PR_NUMBER."

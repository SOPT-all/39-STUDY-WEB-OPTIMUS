#!/usr/bin/env bash
# 모든 PR 의 Discord 스레드를 현재 정책으로 맞춘다(discord-pr-bot.sh 의 닫힘/다시 열림 처리와 같은 규칙).
# - 열린 PR: 보관 해제 + 이름 "PR #N 제목"
# - 머지된 PR: 보관 + 이름 "✅ PR #N 제목"
# - 머지 없이 닫힌 PR: 보관 + 이름 "🗑️ PR #N 제목"
set -euo pipefail

DISCORD_API="https://discord.com/api/v10"
REPO="$GITHUB_REPOSITORY"

gh api --paginate "repos/$REPO/pulls?state=all&per_page=100" \
  --jq '.[] | {number, title, state, merged: (.merged_at != null)} | @json' |
while read -r pr; do
  NUM=$(jq -r '.number' <<< "$pr")
  TITLE=$(jq -r '.title' <<< "$pr")
  STATE=$(jq -r '.state' <<< "$pr")
  MERGED=$(jq -r '.merged' <<< "$pr")

  META=$(gh api --paginate "repos/$REPO/issues/$NUM/comments" \
    --jq '.[] | select(.user.login == "github-actions[bot]") | .body' \
    | grep -oP 'discord-pr-bot: \K\{[^}]*\}' | tail -n 1 || true)
  if [ -z "$META" ]; then
    echo "#$NUM: Discord 스레드 없음 - 건너뜀"
    continue
  fi
  THREAD_ID=$(jq -r '.thread_id' <<< "$META")

  if [ "$STATE" = "open" ]; then
    PREFIX=""; ARCHIVED=false
  elif [ "$MERGED" = "true" ]; then
    PREFIX="✅ "; ARCHIVED=true
  else
    PREFIX="🗑️ "; ARCHIVED=true
  fi
  NAME="${PREFIX}PR #$NUM $TITLE"
  NAME="${NAME:0:90}"

  CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X PATCH "$DISCORD_API/channels/$THREAD_ID" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$(jq -n --arg n "$NAME" --argjson a "$ARCHIVED" '{name: $n, archived: $a, locked: false}')")
  if [ "$CODE" = "200" ]; then
    echo "#$NUM: $NAME (archived=$ARCHIVED)"
  else
    echo "::warning::#$NUM 스레드 변경 실패 (HTTP $CODE)"
  fi

  # 스레드 이름 변경은 Discord rate limit 이 빡빡해서 PR 사이에 쉬어 간다
  sleep 1
done

#!/usr/bin/env bash
# GitHub Release 가 발행되면 릴리즈 노트를 Discord 채널로 알린다.
set -euo pipefail

REPO="$GITHUB_REPOSITORY"
REPO_NAME="${REPO#*/}"

RELEASE=$(gh api "repos/$REPO/releases/tags/$TAG_NAME")
URL=$(jq -r '.html_url' <<< "$RELEASE")
# 릴리즈 노트의 첫 줄(## [1.0.0](compare 링크) (날짜))은 버전 제목과 겹치므로 빼고,
# 커밋/PR 링크는 <> 로 감싸 Discord 링크 미리보기 카드를 막는다
NOTES=$(jq -r '.body // ""' <<< "$RELEASE" \
  | sed -E '1{/^#+ .*[0-9]+\.[0-9]+\.[0-9]+/d;}' \
  | sed -E 's/\]\((https?:[^)]+)\)/](<\1>)/g' \
  | sed '/./,$!d')

TEXT=$(cat <<EOF
🚀 **[$REPO_NAME $TAG_NAME]($URL)** 릴리즈

${NOTES:-변경 사항 없음}
EOF
)
TEXT="${TEXT:0:1900}"

RESP=$(curl -sS -X POST "https://discord.com/api/v10/channels/$DISCORD_CHANNEL_ID/messages" \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  --data "$(jq -n --arg c "$TEXT" '{content: $c, allowed_mentions: {parse: []}}')")

[ -n "$(jq -r '.id // empty' <<< "$RESP")" ] || { echo "Discord post failed: $RESP"; exit 1; }
echo "Posted release $TAG_NAME to Discord."

#!/usr/bin/env bash
# PR 의 커밋 메시지와 PR 제목이 README 컨벤션을 지키는지 검사한다.
# - 커밋 메시지: .githooks/commit-msg 를 커밋마다 실행(로컬 훅과 같은 규칙)
# - PR 제목: [Week {n}][Test|Main] {작업명}
# 결과는 PR 댓글 하나에 기록하고, 이후 실행에서는 그 댓글을 수정한다.
set -uo pipefail

REPO="$GITHUB_REPOSITORY"
MARKER="<!-- commit-convention -->"
TITLE_PATTERN='^\[Week [0-9]+\]\[(Test|Main)\] .+'

FAILED_COMMITS=""
MSG_FILE=$(mktemp)

for sha in $(git rev-list --no-merges --reverse "$BASE_SHA..$HEAD_SHA"); do
  git log -1 --format=%B "$sha" > "$MSG_FILE"
  if ! bash .githooks/commit-msg "$MSG_FILE" 2> /dev/null; then
    FAILED_COMMITS+="| \`${sha:0:7}\` | $(head -n 1 "$MSG_FILE" | sed 's/|/\\|/g') |"$'\n'
  fi
done

TITLE_OK=true
# release-please 가 여는 릴리즈 PR 은 Week 형식이 아니므로 제목 검사에서 제외
if [[ "$HEAD_REF" != release-please--* ]] && ! [[ "$PR_TITLE" =~ $TITLE_PATTERN ]]; then
  TITLE_OK=false
fi

if [ -z "$FAILED_COMMITS" ] && [ "$TITLE_OK" = true ]; then
  BODY="$MARKER
✅ **컨벤션 검사 통과** — 커밋 메시지와 PR 제목이 모두 컨벤션을 지키고 있어요."
  RESULT=0
else
  BODY="$MARKER
❌ **컨벤션 검사 실패**
"
  if [ -n "$FAILED_COMMITS" ]; then
    BODY+="
### 커밋 메시지
| 커밋 | 메시지 |
| :-- | :-- |
$FAILED_COMMITS
형식: \`{type}: {작업 내용}\` (type: \`feat\` \`fix\` \`refactor\` \`docs\` \`chore\`)
수정 방법: \`git rebase -i\` 로 메시지를 고친 뒤 \`git push --force-with-lease\`
"
  fi
  if [ "$TITLE_OK" = false ]; then
    BODY+="
### PR 제목
- 입력: \`$PR_TITLE\`
- 형식: \`[Week {n}][Test] {작업명}\` 또는 \`[Week {n}][Main] {작업명}\`
"
  fi
  RESULT=1
fi

# 기존 결과 댓글이 있으면 수정, 없으면 실패했을 때만 새로 단다(통과만 했을 땐 조용히)
COMMENT_ID=$(gh api --paginate "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq ".[] | select(.user.login == \"github-actions[bot]\" and (.body | startswith(\"$MARKER\"))) | .id" | tail -n 1)

if [ -n "$COMMENT_ID" ]; then
  gh api -X PATCH "repos/$REPO/issues/comments/$COMMENT_ID" -f body="$BODY" > /dev/null
elif [ "$RESULT" -ne 0 ]; then
  gh api "repos/$REPO/issues/$PR_NUMBER/comments" -f body="$BODY" > /dev/null
fi

echo "$BODY"
exit "$RESULT"

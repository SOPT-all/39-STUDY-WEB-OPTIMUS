#!/usr/bin/env bash
# PR 의 커밋 메시지와 PR 제목이 README 컨벤션을 지키는지 검사한다.
# - 커밋 메시지: commit-msg 훅(로컬 훅과 같은 규칙)을 커밋마다 실행
# - PR 제목: [Week {n}][Test|Main] {작업명}
# 결과는 passed / body 로 GITHUB_OUTPUT 에 남기고, 댓글 작성은 워크플로의 별도 job 이 한다.
set -uo pipefail

MARKER="<!-- commit-convention -->"
TITLE_PATTERN='^\[Week [0-9]+\]\[(Test|Main)\] .+'
# 워크플로는 base 브랜치의 규칙을 $RULES 에 꺼내 두고, 로컬 실행 땐 저장소의 훅을 쓴다
HOOK="${RULES:-.githooks}/commit-msg"

write_output() {
  {
    echo "passed=$1"
    echo "body<<__CONVENTION_EOF__"
    echo "$2"
    echo "__CONVENTION_EOF__"
  } >> "$GITHUB_OUTPUT"
  echo "$2"
}

# 커밋 목록 조회가 실패하면 검사 대상이 비어 통과해버리므로, 먼저 확인하고 실패로 처리한다
if ! COMMITS=$(git rev-list --no-merges --reverse "$BASE_SHA..$HEAD_SHA"); then
  write_output false "$MARKER
❌ **컨벤션 검사 실패** — PR 커밋 목록을 가져오지 못해 검사하지 못했어요. 워크플로를 다시 실행해주세요."
  exit 0
fi

FAILED_COMMITS=""
MSG_FILE=$(mktemp)

for sha in $COMMITS; do
  git log -1 --format=%B "$sha" > "$MSG_FILE"
  if ! bash "$HOOK" "$MSG_FILE" 2> /dev/null; then
    FAILED_COMMITS+="| \`${sha:0:7}\` | $(head -n 1 "$MSG_FILE" | sed 's/|/\\|/g') |"$'\n'
  fi
done

TITLE_OK=true
# release-please 가 여는 릴리즈 PR 은 Week 형식이 아니므로 제목 검사에서 제외
if [[ "$HEAD_REF" != release-please--* ]] && ! [[ "$PR_TITLE" =~ $TITLE_PATTERN ]]; then
  TITLE_OK=false
fi

if [ -z "$FAILED_COMMITS" ] && [ "$TITLE_OK" = true ]; then
  write_output true "$MARKER
✅ **컨벤션 검사 통과** — 커밋 메시지와 PR 제목이 모두 컨벤션을 지키고 있어요."
  exit 0
fi

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
write_output false "$BODY"

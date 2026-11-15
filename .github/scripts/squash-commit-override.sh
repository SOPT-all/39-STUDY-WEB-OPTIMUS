#!/usr/bin/env bash
# squash merge 지원 — release-please 가 실행되기 전에 main 으로 들어온 커밋을 확인한다.
#
# squash merge 하면 PR 은 main 에 커밋 하나로 남는다. PR 커밋이 하나면 그 커밋 제목이 그대로 쓰여 문제가 없지만,
# 여러 개면 PR 제목([Week 3][Test] ...)이 커밋 제목이 되어 release-please 가 읽지 못하고 릴리즈 노트에서 빠진다.
# 이때 PR 의 개별 커밋 제목을 PR 본문의 BEGIN_COMMIT_OVERRIDE 블록으로 남기면, release-please 가 그 목록을 커밋 메시지 대신 쓴다.
#
# merge commit · rebase merge 에서는 개별 커밋이 main 에 그대로 남으므로 건드리지 않는다.
# (이때 override 를 쓰면 release-please 가 PR 의 커밋마다 같은 목록을 적용해 항목이 중복된다)
set -euo pipefail

REPO="$GITHUB_REPOSITORY"
CONVENTIONAL='^(feat|fix|refactor|docs|chore)(\([^)]+\))?!?: [^[:space:]]'

# 1) squash merge 판별: 이번 push 로 들어온 커밋이 1개이고, 그 커밋의 부모가 1개
#    (merge commit 은 부모 2개, rebase merge 는 PR 커밋 수만큼 들어온다)
if [[ "$BEFORE" =~ ^0+$ ]]; then
  echo "새 브랜치 push - 건너뜀"; exit 0
fi
COUNT=$(gh api "repos/$REPO/compare/$BEFORE...$AFTER" --jq '.total_commits')
PARENTS=$(gh api "repos/$REPO/commits/$AFTER" --jq '.parents | length')
if [ "$COUNT" != "1" ] || [ "$PARENTS" != "1" ]; then
  echo "squash merge 아님 (커밋 ${COUNT}개, 부모 ${PARENTS}개) - 건너뜀"; exit 0
fi

# 2) 커밋 제목이 이미 컨벤션 형식이면(커밋 1개짜리 PR, 컨벤션 형식의 PR 제목) release-please 가 바로 읽는다
TITLE=$(gh api "repos/$REPO/commits/$AFTER" --jq '.commit.message' | head -n 1)
if [[ "$TITLE" =~ $CONVENTIONAL ]]; then
  echo "커밋 제목이 컨벤션 형식 - 건너뜀: $TITLE"; exit 0
fi

# 3) 이 커밋으로 머지된 PR 찾기
PR=$(gh api "repos/$REPO/commits/$AFTER/pulls" \
  --jq "[.[] | select(.merge_commit_sha == \"$AFTER\")][0].number // empty")
if [ -z "$PR" ]; then
  echo "연결된 PR 없음 - 건너뜀"; exit 0
fi

BODY=$(gh api "repos/$REPO/pulls/$PR" --jq '.body // ""')
if grep -q 'BEGIN_COMMIT_OVERRIDE' <<< "$BODY"; then
  echo "#$PR 에 이미 override 가 있음 - 건너뜀"; exit 0
fi

# 4) PR 의 개별 커밋 중 컨벤션 형식인 것만 제목으로 모은다(머지 커밋 · 컨벤션 밖 커밋 제외)
MESSAGES=$(gh api --paginate "repos/$REPO/pulls/$PR/commits" \
  --jq '.[] | select(.parents | length == 1) | .commit.message | split("\n")[0]' \
  | grep -E "$CONVENTIONAL" || true)
if [ -z "$MESSAGES" ]; then
  echo "#$PR 에 컨벤션 형식 커밋 없음 - 건너뜀"; exit 0
fi

# release-please 는 빈 줄로 구분된 메시지를 각각의 항목으로 읽는다
OVERRIDE=$(awk 'NR > 1 { print "" } { print }' <<< "$MESSAGES")
NEW_BODY="$BODY

<!-- squash merge 로 머지되어, 릴리즈 노트에 개별 커밋이 들어가도록 자동으로 추가된 블록이에요 -->
BEGIN_COMMIT_OVERRIDE
$OVERRIDE
END_COMMIT_OVERRIDE"

gh api -X PATCH "repos/$REPO/pulls/$PR" -f body="$NEW_BODY" > /dev/null
echo "#$PR 에 BEGIN_COMMIT_OVERRIDE 추가:"
echo "$OVERRIDE"

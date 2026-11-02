#!/usr/bin/env bash
# Reply to one inline review thread, and optionally resolve it.
#
# Usage: reply-and-resolve.sh -R OWNER/REPO -p PR -c FIRST_COMMENT_ID -f BODY_FILE [-t THREAD_ID]
#   -c  databaseId of the thread's first comment (firstCommentId from fetch-feedback.sh)
#   -f  file holding the reply markdown (a file avoids shell-quoting trouble)
#   -t  GraphQL thread id; when given, the thread is resolved after replying
#
# Requires: gh (authenticated), jq.
set -euo pipefail

repo="" pr="" comment="" body_file="" thread=""
while getopts "R:p:c:f:t:" opt; do
  case "$opt" in
    R) repo="$OPTARG" ;; p) pr="$OPTARG" ;; c) comment="$OPTARG" ;;
    f) body_file="$OPTARG" ;; t) thread="$OPTARG" ;;
    *) echo "bad option" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$pr" ] && [ -n "$comment" ] && [ -f "$body_file" ] || {
  echo "usage: $0 -R OWNER/REPO -p PR -c COMMENT_ID -f BODY_FILE [-t THREAD_ID]" >&2; exit 2; }

reply_url=$(gh api "repos/$repo/pulls/$pr/comments/$comment/replies" \
  -F body=@"$body_file" -q .html_url)
echo "replied: $reply_url"

if [ -n "$thread" ]; then
  resolved=$(gh api graphql -f id="$thread" -f query='
mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' \
    -q .data.resolveReviewThread.thread.isResolved)
  echo "resolved: $resolved"
fi

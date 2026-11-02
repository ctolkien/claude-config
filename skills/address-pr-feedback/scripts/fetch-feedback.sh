#!/usr/bin/env bash
# Fetch all outstanding review feedback on a GitHub PR as one JSON document.
#
# Usage: fetch-feedback.sh [PR_NUMBER] [-R OWNER/REPO]
#   PR_NUMBER defaults to the PR for the current branch.
#   -R defaults to the repo of the current directory.
#
# Output (stdout, JSON):
#   pr, url, headSha, viewer
#   threads[]       unresolved inline review threads (resolvable)
#   reviews[]       review summaries with a non-empty body (not resolvable)
#   issueComments[] top-level PR conversation comments (not resolvable)
#
# Requires: gh (authenticated), jq.
set -euo pipefail

pr=""
repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    -R|--repo) repo="$2"; shift 2 ;;
    *) pr="$1"; shift ;;
  esac
done

repo_args=()
[ -n "$repo" ] && repo_args=(-R "$repo")

if [ -z "$pr" ]; then
  pr=$(gh pr view "${repo_args[@]}" --json number -q .number)
fi
if [ -z "$repo" ]; then
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi
owner="${repo%%/*}"
name="${repo##*/}"

viewer=$(gh api user -q .login)

# Inline review threads (paginated). __typename tells bots from humans.
threads=$(gh api graphql --paginate \
  -F owner="$owner" -F name="$name" -F number="$pr" \
  -f query='
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 50, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line originalLine
          comments(first: 50) {
            nodes {
              databaseId body url createdAt
              author { login __typename }
            }
          }
        }
      }
    }
  }
}' | jq -s --arg viewer "$viewer" '
  [ .[].data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved | not)
    | {
        threadId: .id,
        path, line: (.line // .originalLine), isOutdated,
        author: .comments.nodes[0].author.login,
        isBot: (.comments.nodes[0].author.__typename == "Bot"),
        firstCommentId: .comments.nodes[0].databaseId,
        lastCommentByViewer: (.comments.nodes[-1].author.login == $viewer),
        comments: [ .comments.nodes[] | {id: .databaseId, author: .author.login, body, url, createdAt} ]
      } ]')

meta=$(gh pr view "$pr" -R "$repo" --json url,headRefOid,author)
pr_author=$(jq -r .author.login <<<"$meta")

# Review summary bodies (e.g. Copilot's overview, a human's "Request changes" note).
reviews=$(gh api --paginate "repos/$repo/pulls/$pr/reviews" | jq -s --arg pa "$pr_author" '
  [ .[][] | select((.body // "") != "" and .user.login != $pa)
    | {id, author: .user.login, isBot: (.user.type == "Bot"), state, body, url: .html_url, submittedAt: .submitted_at} ]')

# Top-level conversation comments, excluding the PR author's own.
issue_comments=$(gh api --paginate "repos/$repo/issues/$pr/comments" | jq -s --arg pa "$pr_author" '
  [ .[][] | select(.user.login != $pa)
    | {id, author: .user.login, isBot: (.user.type == "Bot"), body, url: .html_url, createdAt: .created_at} ]')

jq -n \
  --argjson pr "$pr" --arg repo "$repo" --arg viewer "$viewer" \
  --argjson meta "$meta" --argjson threads "$threads" \
  --argjson reviews "$reviews" --argjson issueComments "$issue_comments" '
  { repo: $repo, pr: $pr, url: $meta.url, headSha: $meta.headRefOid, prAuthor: $meta.author.login, viewer: $viewer,
    threads: $threads, reviews: $reviews, issueComments: $issueComments }'

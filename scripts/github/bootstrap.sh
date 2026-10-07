#!/usr/bin/env bash
# One-time GitHub bootstrap for OpenNetIQ: labels, milestones, backlog issues, develop branch, branch protection.
# Usage: ./scripts/github/bootstrap.sh <owner>/<repo>
# Requires: gh (authenticated: `gh auth login`), jq (Windows: winget install jqlang.jq). Idempotent: safe to re-run.
set -euo pipefail
REPO="${1:?usage: bootstrap.sh <owner>/<repo>}"
OWNER="${REPO%%/*}"
DIR="$(cd "$(dirname "$0")" && pwd)"
command -v gh >/dev/null || { echo "gh CLI required"; exit 1; }
command -v jq >/dev/null || { echo "jq required"; exit 1; }

echo "==> Labels"
jq -c '.labels[]' "$DIR/backlog.json" | while read -r l; do
  name="$(jq -r .name <<<"$l")"
  gh label create "$name" --repo "$REPO" --color "$(jq -r .color <<<"$l")" --description "$(jq -r .description <<<"$l")" --force >/dev/null && echo "  $name"
done

echo "==> Milestones"
existing_ms="$(gh api "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title')"
jq -c '.milestones[]' "$DIR/backlog.json" | while read -r m; do
  title="$(jq -r .title <<<"$m")"
  if grep -Fxq "$title" <<<"$existing_ms"; then echo "  exists: $title"; continue; fi
  gh api "repos/$REPO/milestones" -f title="$title" -f description="$(jq -r .description <<<"$m")" >/dev/null && echo "  $title"
done

echo "==> Issues"
existing_issues="$(gh issue list --repo "$REPO" --state all --limit 500 --json title --jq '.[].title')"
jq -c '.issues[]' "$DIR/backlog.json" | while read -r i; do
  title="$(jq -r .title <<<"$i")"
  if grep -Fxq "$title" <<<"$existing_issues"; then echo "  exists: $title"; continue; fi
  labels="$(jq -r '.labels | join(",")' <<<"$i")"
  gh issue create --repo "$REPO" --title "$title" --body "$(jq -r .body <<<"$i")" \
     --label "$labels" --milestone "$(jq -r .milestone <<<"$i")" >/dev/null && echo "  $title"
done

echo "==> develop branch"
if ! gh api "repos/$REPO/branches/develop" >/dev/null 2>&1; then
  sha="$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha)"
  gh api "repos/$REPO/git/refs" -f ref=refs/heads/develop -f sha="$sha" >/dev/null
fi
gh api -X PATCH "repos/$REPO" -f default_branch=develop >/dev/null || true

# Approvals = 0 while there is a single maintainer (authors cannot approve their own PR); raise to 1 when contributors join.
echo "==> Branch protection (requires public repo or GitHub Pro/Team)"
for b in main develop; do
  gh api -X PUT "repos/$REPO/branches/$b/protection" --input - >/dev/null <<JSON || echo "  skipped $b (plan does not support protection)"
{"required_status_checks":{"strict":true,"contexts":[]},
 "enforce_admins":false,
 "required_pull_request_reviews":{"required_approving_review_count":0},
 "restrictions":null}
JSON
done

echo "==> CODEOWNERS owner"
echo "  Replace @OWNER with @$OWNER in .github/CODEOWNERS and commit (sed -i 's/@OWNER/@$OWNER/g' .github/CODEOWNERS)."
echo "Done."

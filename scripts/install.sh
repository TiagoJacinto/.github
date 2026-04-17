#!/usr/bin/env bash
# Install auto-add-to-project workflow into a repo.
# Usage: install.sh <owner/repo> [pat-value]
#   Or set ADD_TO_PROJECT_PAT env var and just: install.sh <owner/repo>
#
# This creates a self-contained workflow in the target repo that auto-adds
# new issues to GitHub Project 15 (Everything).
set -euo pipefail

REPO="${1:?Usage: install.sh <owner/repo> [pat-value]}"
PAT="${2:-${ADD_TO_PROJECT_PAT:-}}"

if [ -z "$PAT" ]; then
  echo "Error: PAT required. Pass as arg or set ADD_TO_PROJECT_PAT env var."
  echo "Create a fine-grained PAT at:"
  echo "  https://github.com/settings/personal-access-tokens/new"
  echo "Required permissions: Issues (read), Projects (read/write)"
  exit 1
fi

WORKFLOW='name: Add issue to Everything project
on:
  issues:
    types: [opened]
jobs:
  add-to-project:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1.0.2
        with:
          project-url: https://github.com/users/TiagoJacinto/projects/15
          github-token: \${{ secrets.ADD_TO_PROJECT_PAT }}
'

CONTENT=$(printf '%s' "$WORKFLOW" | base64 -w0)

# Try creating the file
PAYLOAD=$(jq -n \
  --arg msg "Add auto-project workflow" \
  --arg c "$CONTENT" \
  '{message: $msg, content: $c}')

HTTP_CODE=$(gh api \
  "repos/$REPO/contents/.github/workflows/add-to-project.yml" \
  -X PUT --input - \
  -o /dev/null -w "%{http_code}" \
  <<< "$PAYLOAD" 2>/dev/null) || true

if [ "$HTTP_CODE" = "201" ]; then
  echo "Workflow added to $REPO"
elif [ "$HTTP_CODE" = "422" ]; then
  echo "Workflow already exists, updating..."
  SHA=$(gh api "repos/$REPO/contents/.github/workflows/add-to-project.yml" --jq '.sha')
  PAYLOAD=$(jq -n \
    --arg msg "Update auto-project workflow" \
    --arg c "$CONTENT" \
    --arg sha "$SHA" \
    '{message: $msg, content: $c, sha: $sha}')
  gh api "repos/$REPO/contents/.github/workflows/add-to-project.yml" \
    -X PUT --input - <<< "$PAYLOAD" -o /dev/null
  echo "Workflow updated in $REPO"
else
  echo "Warning: unexpected status $HTTP_CODE"
fi

# Set the PAT secret
echo "$PAT" | gh secret set ADD_TO_PROJECT_PAT --repo "$REPO"
echo "Secret set in $REPO"
echo "Done! New issues in $REPO will auto-add to Project 15 (Everything)."

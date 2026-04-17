#!/usr/bin/env bash
# Install auto-add-to-project workflow into a repo.
# Usage: install.sh <owner/repo> [pat-value]
#   Or set ADD_TO_PROJECT_PAT env var and just: install.sh <owner/repo>
set -euo pipefail

REPO="${1:?Usage: install.sh <owner/repo> [pat-value]}"
PAT="${2:-${ADD_TO_PROJECT_PAT:-}}"

if [ -z "$PAT" ]; then
  echo "Error: PAT required. Pass as arg or set ADD_TO_PROJECT_PAT env var."
  echo "Create one at: https://github.com/settings/personal-access-tokens/new"
  echo "Required scopes: repo (full), project (read/write)"
  exit 1
fi

CALLER_WORKFLOW='name: Add issue to project
on:
  issues:
    types: [opened]
jobs:
  add-to-project:
    uses: TiagoJacinto/.github/.github/workflows/add-to-project.yml@main
    secrets: inherit
'

# Create or update the caller workflow file via GitHub API
PAYLOAD=$(jq -n   --arg msg "Add auto-project workflow"   --arg content "$(echo "$CALLER_WORKFLOW" | base64 -w0)"   "{message: \$msg, content: \$content}")

HTTP_CODE=$(gh api   "repos/$REPO/contents/.github/workflows/add-to-project.yml"   -X PUT --input -   -o /dev/null -w "%{http_code}"   <<< "$PAYLOAD" 2>/dev/null) || true

if [ "$HTTP_CODE" = "201" ]; then
  echo "Workflow added to $REPO"
elif [ "$HTTP_CODE" = "422" ]; then
  echo "Workflow already exists in $REPO, updating..."
  SHA=$(gh api "repos/$REPO/contents/.github/workflows/add-to-project.yml" --jq ".sha")
  PAYLOAD=$(jq -n     --arg msg "Update auto-project workflow"     --arg content "$(echo "$CALLER_WORKFLOW" | base64 -w0)"     --arg sha "$SHA"     "{message: \$msg, content: \$content, sha: \$sha}")
  gh api "repos/$REPO/contents/.github/workflows/add-to-project.yml"     -X PUT --input - <<< "$PAYLOAD" -o /dev/null
  echo "Workflow updated in $REPO"
else
  echo "Warning: unexpected status $HTTP_CODE creating workflow in $REPO"
fi

# Set the PAT secret
echo "$PAT" | gh secret set ADD_TO_PROJECT_PAT --repo "$REPO"
echo "Secret set in $REPO"
echo "Done! New issues in $REPO will auto-add to project 15."

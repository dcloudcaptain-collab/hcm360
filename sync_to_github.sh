#!/usr/bin/env bash
# =============================================================================
# HCM360 — Sync local working copy to GitHub
#   macOS / Linux / Git-Bash on Windows
#
# Usage:
#   ./sync_to_github.sh                    # prompts for commit message
#   ./sync_to_github.sh "your message"     # uses arg as commit message
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d .git ]; then
  echo "✗ Not a git repository. Run 'git init' first or clone the repo." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "✗ No 'origin' remote configured." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "→ Branch: $BRANCH"
echo "→ Remote: $(git remote get-url origin)"
echo

git add -A

if git diff --cached --quiet; then
  echo "✓ Nothing to commit. Pushing existing commits (if any)…"
else
  echo "→ Staged changes:"
  git diff --cached --stat | tail -n +1
  echo

  if [ "${1:-}" != "" ]; then
    MSG="$1"
  else
    DEFAULT_MSG="sync $(date '+%Y-%m-%d %H:%M')"
    printf "Commit message [%s]: " "$DEFAULT_MSG"
    read -r MSG
    MSG="${MSG:-$DEFAULT_MSG}"
  fi

  git commit -m "$MSG"
fi

echo
echo "→ Pushing to origin/$BRANCH…"
git push -u origin "$BRANCH"
echo
echo "✓ Done. Latest commit: $(git log --oneline -1)"

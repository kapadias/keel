#!/usr/bin/env bash
# Pre-push git hook — enforces the Definition of Done (see .claude/rules/sync.md):
# a push that changes code must also update docs/STATUS.md.
#
# Install:  ln -sf ../../.claude/hooks/require-status-sync.sh .git/hooks/pre-push
#           chmod +x .claude/hooks/require-status-sync.sh
#
# Bypass (use sparingly, and only when you truly changed no code): git push --no-verify
set -euo pipefail

upstream="origin/$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
range="$upstream..HEAD"
git rev-parse --verify "$upstream" >/dev/null 2>&1 || range="HEAD"

changed="$(git diff --name-only "$range" 2>/dev/null || true)"
[ -n "$changed" ] || exit 0

# Does the push touch code? (everything except docs / .claude prose / config noise)
code_touched="$(printf '%s\n' "$changed" \
  | grep -Ev '^(docs/|\.claude/|README|LICENSE|\.gitignore|.*\.md$)' || true)"

# Does it update the status mirror?
status_touched="$(printf '%s\n' "$changed" | grep -E '^docs/STATUS\.md$' || true)"

if [ -n "$code_touched" ] && [ -z "$status_touched" ]; then
  echo "✗ Definition of Done: code changed but docs/STATUS.md was not updated." >&2
  echo "  Update docs/STATUS.md (see .claude/rules/sync.md), or push --no-verify if truly N/A." >&2
  exit 1
fi
exit 0

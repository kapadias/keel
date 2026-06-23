#!/usr/bin/env bash
# Pre-push git hook — the Definition of Done (rules/sync.md): a push that changes
# CODE must also update docs/STATUS.md, and must not introduce a secret.
#
# Auto-installed by .claude/hooks/session-start.sh, or manually:
#   ln -sf ../../.claude/hooks/require-status-sync.sh .git/hooks/pre-push
# Bypass (only when you truly changed no code): git push --no-verify
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/secret-patterns.sh"

upstream="origin/$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
range="$upstream..HEAD"
git rev-parse --verify "$upstream" >/dev/null 2>&1 || range="HEAD"

changed="$(git diff --name-only "$range" 2>/dev/null || true)"
[ -n "$changed" ] || exit 0

# CODE = everything EXCEPT docs/ and a few top-level meta files. NOTE: .claude/**
# IS code (the harness is a tracked mirror, rules/sync.md) even though it is
# markdown — so harness changes also require a STATUS update.
code_touched="$(printf '%s\n' "$changed" | grep -Ev '^(docs/|LICENSE$|\.gitignore$|[^/]*\.md$)' || true)"
status_touched="$(printf '%s\n' "$changed" | grep -E '^docs/STATUS\.md$' || true)"

fail=0
if [ -n "$code_touched" ] && [ -z "$status_touched" ]; then
  {
    echo "✗ Definition of Done: code changed but docs/STATUS.md was not updated."
    echo "  Update docs/STATUS.md (rules/sync.md), or 'git push --no-verify' if truly N/A."
  } >&2
  fail=1
fi

# Secret scan over added lines, per file, skipping fixture/test/example paths
# (consistent with the write-time gate, so sample-secret fixtures don't trip it).
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if keel_is_test_path "$f"; then continue; fi
  added="$(git diff "$range" -- "$f" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
  [ -n "$added" ] || continue
  if class="$(printf '%s' "$added" | keel_scan_secrets)"; then
    {
      echo "✗ Push blocked: ${f} introduces what looks like a ${class}."
      echo "  Remove it and ROTATE the secret (rules/safety.md). Never push secrets."
    } >&2
    fail=1
  fi
done <<EOF
$changed
EOF

exit "$fail"

#!/usr/bin/env bash
# PreToolUse hook — warn (once per branch) when editing on a protected branch.
# Non-blocking: prints guidance to stderr, always exits 0.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
case "$branch" in
  main|master|develop)
    marker="$root/.git/.keel-branch-warned-$branch"
    if [ ! -f "$marker" ]; then
      touch "$marker" 2>/dev/null || true
      echo "⚠️  On protected branch '$branch'. Branch first: git checkout -b feature/<id>-<slug>" >&2
    fi
    ;;
esac
exit 0

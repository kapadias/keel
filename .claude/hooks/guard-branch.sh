#!/usr/bin/env bash
# PreToolUse gate — protect main/master/develop. Dual-mode by tool:
#   • Edit|Write|MultiEdit on a protected branch  -> WARN once (exit 0).
#       Editing is fine; committing is what's forbidden.
#   • Bash `git commit`/`git merge` on a protected branch, or any `git push`
#     that is on/targets a protected branch -> BLOCK (exit 2).
# This makes "never commit to main/develop" a real gate, not just prose.
# Fails SAFE: if the branch can't be determined, it never blocks.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/json.sh"

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"

is_protected() { case "$1" in main | master | develop) return 0 ;; *) return 1 ;; esac; }

payload="$(cat 2>/dev/null || true)"
tool="$(printf '%s' "$payload" | keel_json_field '.tool_name')"

case "$tool" in
  Edit | Write | MultiEdit)
    if is_protected "$branch"; then
      marker="$root/.git/.keel-branch-warned-$branch"
      if [ ! -f "$marker" ]; then
        touch "$marker" 2>/dev/null || true
        echo "⚠️  On protected branch '$branch'. Editing is fine, but do NOT commit here — branch first: git checkout -b feature/<id>-<slug>" >&2
      fi
    fi
    exit 0
    ;;
  Bash)
    cmd="$(printf '%s' "$payload" | keel_json_field '.tool_input.command')"
    [ -n "$cmd" ] || exit 0

    # Block a commit/merge while sitting on a protected branch.
    if is_protected "$branch" \
      && printf '%s' "$cmd" | grep -qE '(^|[;&|]|[[:space:]])git[[:space:]]+(commit|merge)([[:space:]]|$)'; then
      echo "✗ Keel branch guard: refusing to commit on protected branch '$branch'." >&2
      echo "  Never commit to main/master/develop (rules/git-workflow.md). Branch first:" >&2
      echo "    git checkout -b feature/<id>-<slug>" >&2
      exit 2
    fi

    # Block a push that is on, or targets, a protected branch (forced or not).
    if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push'; then
      if is_protected "$branch" \
        || printf '%s' "$cmd" | grep -qE '(:|[[:space:]])(main|master|develop)([[:space:]]|$)'; then
        echo "✗ Keel branch guard: refusing to push to a protected branch." >&2
        echo "  Promote via PR (feature -> develop -> main), not a direct push (rules/git-workflow.md)." >&2
        exit 2
      fi
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

#!/usr/bin/env bash
# PreToolUse gate — protect main/master/develop. Dual-mode by tool:
#   • Edit|Write|MultiEdit on a protected branch  -> WARN once (exit 0).
#       Editing is fine; committing is what's forbidden.
#   • Bash `git commit`/`git merge` on a protected branch, or any `git push`
#     that is on/targets a protected branch (or pushes --all/--mirror) -> BLOCK.
# The git matcher tolerates a path prefix (/usr/bin/git) and global options
# (`-C <dir>`, `--git-dir`, `-c k=v`, …) between `git` and the subcommand, so the
# guard is not defeated by `git -C . commit`. Fails SAFE: if the branch can't be
# determined, it never blocks. Client-side hooks are the first line; the pre-push
# DoD gate and CI are the hard backstops (see ADR 0004).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/json.sh"

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"

is_protected() { case "$1" in main | master | develop) return 0 ;; *) return 1 ;; esac; }

# `git` (optionally path-prefixed) + any run of global options, up to a subcommand.
GIT='(^|[;&|]|[[:space:]])([^[:space:]]*/)?git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)|--[A-Za-z][A-Za-z-]*|-[A-Za-z]))*[[:space:]]+'

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

    # Commit/merge while sitting on a protected branch.
    if is_protected "$branch" && printf '%s' "$cmd" | grep -qE "$GIT"'(commit|merge)([[:space:]]|$)'; then
      echo "✗ Keel branch guard: refusing to commit on protected branch '$branch'." >&2
      echo "  Never commit to main/master/develop (rules/git-workflow.md). Branch first:" >&2
      echo "    git checkout -b feature/<id>-<slug>" >&2
      exit 2
    fi

    # Push handling.
    if printf '%s' "$cmd" | grep -qE "$GIT"'push([[:space:]]|$)'; then
      # --all / --mirror push (or delete) every local ref, incl. protected ones.
      if printf '%s' "$cmd" | grep -qE -e '[[:space:]]--(all|mirror)([[:space:]]|=|$)'; then
        echo "✗ Keel branch guard: refusing 'git push --all/--mirror' — it pushes (or deletes) protected refs." >&2
        echo "  Push one branch explicitly: git push origin <feature-branch> (rules/git-workflow.md)." >&2
        exit 2
      fi
      # A refspec with a leading '+' is a force push in refspec syntax — parity
      # with the blanket --force/--force-with-lease/-f denies in settings.json.
      if printf '%s' "$cmd" | grep -qE '[[:space:]]\+[^[:space:]]+'; then
        echo "✗ Keel branch guard: refusing 'git push' with a +refspec — that is a force push." >&2
        echo "  Force-pushing is denied (settings.json, rules/git-workflow.md); push a new commit instead." >&2
        exit 2
      fi
      # On a protected branch, or naming a protected ref as the target.
      if is_protected "$branch" || printf '%s' "$cmd" | grep -qE '(:|/|[[:space:]])(main|master|develop)([[:space:]]|$)'; then
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

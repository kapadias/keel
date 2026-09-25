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
# shellcheck source=/dev/null
. "$here/lib/core.sh"
[ "$(nonna_mode)" = off ] && exit 0 # off means off: nothing enforced, nothing said
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"

is_protected() { case "$1" in main | master | develop) return 0 ;; *) return 1 ;; esac; }

# `git` (optionally path-prefixed) + any run of global options, up to a subcommand.
GIT='(^|[;&|]|[[:space:]])([^[:space:]]*/)?git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir(=[^[:space:]]+|[[:space:]]+[^[:space:]]+)|--[A-Za-z][A-Za-z-]*|-[A-Za-z]))*[[:space:]]+'

payload="$(cat 2>/dev/null || true)"
tool="$(printf '%s' "$payload" | nonna_json_field '.tool_name')"

case "$tool" in
  Edit | Write | MultiEdit)
    if is_protected "$branch"; then
      marker="$root/.git/.nonna-branch-warned-$branch"
      if [ ! -f "$marker" ]; then
        touch "$marker" 2>/dev/null || true
        echo "⚠️  On protected branch '$branch'. Editing is fine, but do NOT commit here — branch first: git checkout -b feature/<id>-<slug>" >&2
      fi
    fi
    exit 0
    ;;
  Bash)
    cmd="$(printf '%s' "$payload" | nonna_json_field '.tool_input.command')"
    [ -n "$cmd" ] || exit 0
    # The command with its quoted strings removed, so a commit message that mentions a flag is not
    # read as the flag. The +refspec check below keeps the quoted form on purpose.
    bare="$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"

    # Nonna's own switches (git config nonna.*) belong to the user, who changes them with /nonna. The
    # agent may read them; a write, in any segment of a compound command, is refused.
    # shellcheck disable=SC2020  # tr maps each of ; & | to a newline: one segment per line
    while IFS= read -r seg; do
      printf '%s' "$seg" | grep -qE "$GIT"'config([[:space:]]|$)' || continue
      printf '%s' "$seg" | grep -qiE '(^|[[:space:]])nonna(\.|[[:space:]]|$)' || continue
      printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])(--get|--get-all|--get-regexp|--list|-l)([[:space:]]|$)' && continue
      echo "✗ Nonna: only the cook changes the recipe. (branch guard: refusing to change Nonna's own git config.)" >&2
      echo "  Her settings are the user's: they change them with /nonna." >&2
      exit 2
    done < <(printf '%s\n' "$bare" | tr ';&|' '\n\n\n')

    # The git hooks are the gate for a commit and a push, so skipping them is refused: --no-verify,
    # commit's -n, and pointing core.hooksPath elsewhere. A speed bump, not a wall: git commit-tree
    # and update-ref still get around it, and the pre-push hook is the backstop (ADR-0004).
    if printf '%s' "$bare" | grep -qE "$GIT"'(commit|push|merge|am|rebase|cherry-pick|revert)[^;&|]*[[:space:]]--no-verify([[:space:]]|$)' \
      || printf '%s' "$bare" | grep -qE "$GIT"'commit[^;&|]*[[:space:]]-[A-Za-z]*n[A-Za-z]*([[:space:]]|$)' \
      || printf '%s' "$bare" | grep -qiE '(^|[;&|[:space:]])([^[:space:]]*/)?git([[:space:]][^;&|]*)?[[:space:]]core\.hookspath'; then
      echo "✗ Nonna: no sneaking past the kitchen door. (branch guard: refusing --no-verify and hook overrides; the git hooks are the gate.)" >&2
      echo "  Fix what the hook refuses, or tell the user plainly why you cannot." >&2
      exit 2
    fi

    # Commit/merge while sitting on a protected branch.
    if is_protected "$branch" && printf '%s' "$cmd" | grep -qE "$GIT"'(commit|merge)([[:space:]]|$)'; then
      echo "✗ Nonna: not in my kitchen, tesoro. Make a branch. (branch guard: refusing to commit on protected branch '$branch'.)" >&2
      echo "  Never commit to main/master/develop (rules/git-workflow.md). Branch first:" >&2
      echo "    git checkout -b feature/<id>-<slug>" >&2
      exit 2
    fi

    # Push handling.
    if printf '%s' "$cmd" | grep -qE "$GIT"'push([[:space:]]|$)'; then
      # --all / --mirror push (or delete) every local ref, incl. protected ones.
      if printf '%s' "$cmd" | grep -qE -e '[[:space:]]--(all|mirror)([[:space:]]|=|$)'; then
        echo "✗ Nonna: one pot at a time. (branch guard: refusing 'git push --all/--mirror' — it pushes (or deletes) protected refs.)" >&2
        echo "  Push one branch explicitly: git push origin <feature-branch> (rules/git-workflow.md)." >&2
        exit 2
      fi
      # Flag-form force pushes. settings.json denies them for a copy-in install, but a plugin cannot
      # carry permissions, so the hook must. Scoped to the push segment; a short-flag cluster (-uf)
      # counts, --follow-tags does not.
      if printf '%s' "$bare" | grep -qE "$GIT"'push[^;&|]*[[:space:]](--force(-with-lease)?(=[^[:space:]]*)?|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|$)'; then
        echo "✗ Nonna: we don't force things in this house. (branch guard: refusing a force push.)" >&2
        echo "  Push a new commit instead (rules/git-workflow.md)." >&2
        exit 2
      fi
      # A refspec with a leading '+' is a force push in refspec syntax — parity with the
      # blanket --force/--force-with-lease/-f denies in settings.json. Scope the match to
      # the push invocation's own segment (`push[^;&|]*`) so a '+' in an earlier compound
      # command — a commit message, a chmod +x — cannot false-block a normal push; tolerate
      # an optional opening quote so `git push origin "+main"` is still caught.
      if printf '%s' "$cmd" | grep -qE "$GIT"'push[^;&|]*[[:space:]]'"[\"']"'?\+[^[:space:]]'; then
        echo "✗ Nonna: we don't force things in this house. (branch guard: refusing 'git push' with a +refspec — that is a force push.)" >&2
        echo "  Force-pushing is denied (settings.json, rules/git-workflow.md); push a new commit instead." >&2
        exit 2
      fi
      # On a protected branch, or naming a protected ref as the target.
      if is_protected "$branch" || printf '%s' "$cmd" | grep -qE '(:|/|[[:space:]])(main|master|develop)([[:space:]]|$)'; then
        echo "✗ Nonna: nobody pushes to main in my house. Open a PR. (branch guard: refusing to push to a protected branch.)" >&2
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

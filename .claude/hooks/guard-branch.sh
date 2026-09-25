#!/usr/bin/env bash
# PreToolUse gate — protect main/master/develop, and the gates themselves. Dual-mode by tool:
#   • Edit|Write|MultiEdit on a protected branch  -> WARN once (exit 0).
#       Editing is fine; committing is what's forbidden. Editing .git/config or .git/hooks -> BLOCK.
#   • Bash `git commit`/`git merge` on a protected branch, or any `git push`
#     that is on/targets a protected branch (or pushes --all/--mirror) -> BLOCK. So is a force
#     push, skipping the git hooks, and changing what Nonna's gates read.
# The command is read the way the shell will run it: continued lines joined, a quoted commit message
# masked, quotes and backslashes removed, and ( ), $( ) and backticks opened into commands of their
# own. The git matcher tolerates a path prefix (/usr/bin/git) and global options (`-C <dir>`,
# `--git-dir`, `-c k=v`, …) between `git` and the subcommand, and git's abbreviated long options.
# A speed bump, not a sandbox: a script file, a shell variable or an alias the user already has
# still gets past it. Branch protection on the server is the wall (ADR-0011). Fails SAFE: if the
# branch can't be determined, it never blocks on it.
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

# `git` (optionally path-prefixed) + any run of global options, up to a subcommand. A command starts
# a line, or follows a space, `{` or `!`.
GIT='(^|[[:space:]{!])([^[:space:]]*/)?git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path|super-prefix|config-env)(=[^[:space:]]*|[[:space:]]+[^[:space:]]+)|--[A-Za-z][A-Za-z-]*(=[^[:space:]]*)?|-[A-Za-z]))*[[:space:]]+'
# Config keys that are Nonna's own switches, and keys that can route git around her hooks: an
# include, an alias, a hooks path, a mirror or forced push refspec. Matched without case.
NKEY='nonna([.[:space:]=]|$)'
RKEY='(include(if)?\.|alias\.|core\.hookspath|remote\.[^[:space:]]*\.(mirror|push[=[:space:]]+\+))'

recipe() { # <technical reason>: her settings are the user's
  echo "✗ Nonna: only the cook changes the recipe. (branch guard: $1)" >&2
  echo "  Her settings are the user's: they change them with /nonna." >&2
  exit 2
}
kitchen_door() { # <technical reason>: the git hooks are the gate
  echo "✗ Nonna: no sneaking past the kitchen door. (branch guard: $1)" >&2
  echo "  Fix what the hook refuses, or tell the user plainly why you cannot." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"
tool="$(printf '%s' "$payload" | nonna_json_field '.tool_name')"

case "$tool" in
  Edit | Write | MultiEdit)
    # Her settings and her git hooks are the user's: the file tools may not rewrite them either.
    file="$(printf '%s' "$payload" | nonna_json_field '.tool_input.file_path')"
    case "/${file#./}" in
      */.git/config | */.git/hooks/* | */.git/nonna/* | */.git/nonna-green)
        recipe "refusing to edit ${file}: her settings and git hooks live there." ;;
    esac
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
    # How the shell will see it. A quoted commit message (-m, --message, -F, --file) is masked
    # first, so a message that mentions --no-verify or main is not read as a flag or a ref; then
    # quotes and backslashes go, as the shell removes them: "--force", --for"ce", $'-f' and \git
    # all reach git as plain words.
    norm="${cmd//$'\\\n'/ }"
    norm="$(printf '%s' "$norm" | sed -E \
      -e "s/(^|[[:space:]])(-[A-Za-z]*m|--message|-F|--file)(=|[[:space:]]+)(\"[^\"]*\"|'[^']*')/\\1\\2 MSG/g" \
      -e "s/[\$]'/'/g")"
    norm="$(printf '%s' "$norm" | tr -d "\"'\\\\")"
    # One command per line: ; & | ( ) and backticks each end one.
    # shellcheck disable=SC2020  # tr maps each of those characters to a newline
    segs="$(printf '%s\n' "$norm" | tr ';&|()`' '\n\n\n\n\n\n')"
    runs_git() { printf '%s\n' "$segs" | grep -qE "${GIT}[a-z]"; }

    # What her gates read is the user's to set: an environment variable can switch a git hook off
    # or swap its test command, GIT_CONFIG_* and a borrowed HOME can hand git a config of their own.
    if printf '%s' "$norm" | grep -qE '(^|[^A-Za-z0-9_])(NONNA_MODE|NONNA_TEST_CMD|CLAUDE_PLUGIN_OPTION_[A-Za-z0-9_]+|GIT_CONFIG[A-Za-z0-9_]*)=' \
      || { printf '%s' "$norm" | grep -qE '(^|[^A-Za-z0-9_])(HOME|XDG_CONFIG_HOME)=' && runs_git; }; then
      recipe "refusing to set what her gates read: NONNA_MODE, NONNA_TEST_CMD, CLAUDE_PLUGIN_OPTION_*, GIT_CONFIG_*, or HOME for git."
    fi

    # Config on the command line (-c, --config-env) that switches her off or routes git around her.
    if printf '%s\n' "$segs" | grep -qiE "(^|[[:space:]{!])([^[:space:]]*/)?git[[:space:]](.*[[:space:]])?(-c[[:space:]]+|--config-env[=[:space:]]+)${NKEY}"; then
      recipe "refusing to change Nonna's own git config."
    fi
    if printf '%s\n' "$segs" | grep -qiE "(^|[[:space:]{!])([^[:space:]]*/)?git[[:space:]](.*[[:space:]])?(-c[[:space:]]+|--config-env[=[:space:]]+)${RKEY}"; then
      kitchen_door "refusing an include, alias, hooks path or forced refspec on the command line; the git hooks are the gate."
    fi

    # git config: a read is fine (--get*, --list, -l, or the get/list subcommand); a write to her
    # keys, or to one that reroutes git, is refused in any command of a compound line.
    while IFS= read -r seg; do
      printf '%s' "$seg" | grep -qE "${GIT}config([[:space:]]|$)" || continue
      printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])(--get[a-z-]*|--list|-l)([[:space:]=]|$)' && continue
      printf '%s' "$seg" | grep -qE "${GIT}config([[:space:]]+-[^[:space:]]+)*[[:space:]]+(get|list)([[:space:]]|$)" && continue
      printf '%s' "$seg" | grep -qiE "(^|[[:space:]])${NKEY}" && recipe "refusing to change Nonna's own git config."
      if printf '%s' "$seg" | grep -qiE "(^|[[:space:]])(${RKEY}|(-e|--edit|edit)([[:space:]]|$))"; then
        kitchen_door "refusing a config change that can route git around her hooks (include, alias, core.hooksPath, a forced refspec, --edit)."
      fi
    done <<<"$segs"

    # The same files by hand: .git/config and the git hooks.
    if printf '%s\n' "$segs" | grep -qE '>>?[[:space:]]*[^[:space:]]*\.git/(hooks|config)' \
      || printf '%s\n' "$segs" | grep -E '(^|[^A-Za-z0-9_.-])\.git/(hooks([/[:space:]]|$)|config([[:space:]]|$))' \
      | grep -qE '(^|[[:space:]])(rm|mv|cp|ln|chmod|chown|tee|truncate|install|touch|unlink|shred|dd|patch|ed|ex|vi|vim|nano|emacs|sed|perl|python3?|ruby|node|awk)([[:space:]]|$)'; then
      recipe "refusing to change .git/config or .git/hooks by hand."
    fi

    # The git hooks are the gate for a commit and a push, so skipping them is refused: --no-verify
    # (and its abbreviations) and commit's -n, alone or in a cluster of flags that take no value.
    if printf '%s\n' "$segs" | grep -qE "${GIT}(commit|push|merge|am|rebase|cherry-pick|revert|pull)([[:space:]].*)?[[:space:]]--no-veri[a-z]*([=[:space:]]|$)" \
      || printf '%s\n' "$segs" | grep -qE "${GIT}commit([[:space:]].*)?[[:space:]]-[aeiopqsvz]*n"; then
      kitchen_door "refusing --no-verify and hook overrides; the git hooks are the gate."
    fi

    # Commit/merge while sitting on a protected branch.
    if is_protected "$branch" && printf '%s\n' "$segs" | grep -qE "${GIT}(commit|merge)([[:space:]]|$)"; then
      echo "✗ Nonna: not in my kitchen, tesoro. Make a branch. (branch guard: refusing to commit on protected branch '$branch'.)" >&2
      echo "  Never commit to main/master/develop (rules/git-workflow.md). Branch first:" >&2
      echo "    git checkout -b feature/<id>-<slug>" >&2
      exit 2
    fi

    # Push handling, on the push commands alone.
    push="$(printf '%s\n' "$segs" | grep -E "${GIT}push([[:space:]]|$)" || true)"
    if [ -n "$push" ]; then
      # --all / --mirror push (or delete) every local ref, incl. protected ones.
      if printf '%s\n' "$push" | grep -qE '[[:space:]]--(al|all|mi|mir|mirr|mirro|mirror)([=[:space:]]|$)'; then
        echo "✗ Nonna: one pot at a time. (branch guard: refusing 'git push --all/--mirror' — it pushes (or deletes) protected refs.)" >&2
        echo "  Push one branch explicitly: git push origin <feature-branch> (rules/git-workflow.md)." >&2
        exit 2
      fi
      # Force pushes: --force and --force-with-lease (git takes any unique abbreviation, from --for),
      # and -f alone or in a cluster of flags that take no value (-uf). --follow-tags is not one.
      if printf '%s\n' "$push" | grep -qE '(^|[[:space:]{,])(--for[a-z-]*(=[^[:space:]]*)?|-[unvqd46]*f)'; then
        echo "✗ Nonna: we don't force things in this house. (branch guard: refusing a force push.)" >&2
        echo "  Push a new commit instead (rules/git-workflow.md)." >&2
        exit 2
      fi
      # A refspec with a leading '+' is a force push in refspec syntax.
      if printf '%s\n' "$push" | grep -qE '(^|[[:space:]{,])\+[^[:space:]]'; then
        echo "✗ Nonna: we don't force things in this house. (branch guard: refusing 'git push' with a +refspec — that is a force push.)" >&2
        echo "  Force-pushing is denied (settings.json, rules/git-workflow.md); push a new commit instead." >&2
        exit 2
      fi
      # On a protected branch, or naming a protected ref as the target (main:feature only reads main).
      if is_protected "$branch" || printf '%s\n' "$push" | grep -qE '(^|[[:space:]:/{,])(main|master|develop)([[:space:]},]|$)'; then
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

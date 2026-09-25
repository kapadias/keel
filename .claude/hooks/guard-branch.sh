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
# a line, or follows a space, `{`, `!` or `=` (a command in a value: GIT_EDITOR=…, --exec=…).
GIT='(^|[[:space:]{!=])([^[:space:]]*/)?git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path|super-prefix|config-env|attr-source|shallow-file)(=[^[:space:]]*|[[:space:]]+[^[:space:]]+)|--[A-Za-z][A-Za-z-]*(=[^[:space:]]*)?|-[A-Za-z]))*[[:space:]]+'
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
    # How the shell will see it (lib/shell-words.awk). Readings, checked together: A keeps each word
    # whole, so a quoted value with a space cannot shift the words after it; B exposes what a quoted
    # string holds, so code in sh -c "…" or "$(…)" is seen; and B read again, masking nothing, while a
    # quote or an escape is left in it (up to six times), so a quote nested inside one (sh -c '…
    # "--force"') is removed as the inner shell removes it. Nesting deeper than that is refused. A
    # message is masked only where the reading is sure to be the shell's. A match in any refuses.
    # Without awk: quotes deleted, nothing masked, which can only refuse more.
    words() { printf '%s\n' "$cmd" | awk -v out="$1" -f "$here/lib/shell-words.awk" 2>/dev/null; }
    quoted() { case "$1" in *[\'\"\\]*) return 0 ;; esac; return 1; }
    lvl="$(words B)"
    segs="$(words A)"$'\n'"$lvl"
    n=0
    while [ "$n" -lt 6 ] && quoted "$lvl"; do
      next="$(printf '%s\n' "$lvl" | awk -v out=B -v nomask=1 -v relevel=1 -f "$here/lib/shell-words.awk" 2>/dev/null)"
      [ "$next" = "$lvl" ] && break
      segs="$segs"$'\n'"$next"
      lvl="$next"
      n=$((n + 1))
    done
    if [ "$n" -ge 6 ] && quoted "$lvl"; then
      kitchen_door "refusing quotes nested deeper than the guard reads; run the inner command itself."
    fi
    if [ -z "${segs//[[:space:]]/}" ]; then
      # shellcheck disable=SC2020  # tr maps each of those characters to a newline
      segs="$(printf '%s\n' "$cmd" | tr -d "\"'\\\\" | tr ';&|()`' '\n\n\n\n\n\n')"
    fi
    runs_git() { printf '%s\n' "$segs" | grep -qE "${GIT}[a-z]"; }
    RD=$'\002' # the mark shell-words.awk puts before a redirection the shell performs

    # What her gates read is the user's to set: an environment variable can switch a git hook off
    # or swap its test command, GIT_CONFIG_* and a borrowed HOME can hand git a config of their own.
    # Only a way of setting one counts. One that carries a value counts wherever it stands: a name=
    # given to export, declare and the like, or to env or sudo (behind builtin, command, nice,
    # timeout, a redirection or a trap string alike), and an assignment right before git. A bare
    # assignment, and a name given without a value (export NAME, read NAME, printf -v NAME), count at
    # the start of a command: after { ! if then do else elif while until time eval coproc, builtin,
    # command, other assignments, redirections, or sh -c and its kind (whose text B puts on the same
    # line). A grep for the name, or an echo of it, sets nothing.
    ASSIGN='[A-Za-z_][A-Za-z0-9_]*\+?=[^[:space:]]*'
    KW='(\{|!|if|then|do|else|elif|while|until|time([[:space:]]+-p)?|eval|coproc|builtin|command([[:space:]]+-[A-Za-z]+)*|[^[:space:]]*(sh|bash|zsh|dash|ksh)([[:space:]]+-[A-Za-z]+)*[[:space:]]+-[A-Za-z]*c)'
    # A redirection (marked by shell-words.awk, or bare without awk) may come first; taking more
    # for a command's start only ever refuses more.
    AT="^[[:space:]]*((${KW}|${ASSIGN}|${RD}?[0-9]*[<>]+([[:space:]]+${RD}?[<>]+)*[[:space:]]*[^[:space:]]+)[[:space:]]+)*"
    DECL='(export|declare|typeset|readonly|local)([[:space:]]+-[A-Za-z]+)*'
    assigns() { # <name regex>
      printf '%s\n' "$segs" | grep -qE \
        -e "${AT}$1\+?=" \
        -e "(^|[[:space:]])${DECL}([[:space:]]+${ASSIGN})*[[:space:]]+$1\+?=" \
        -e "(^|[[:space:]])(env|sudo)[[:space:]](.*[[:space:]])?$1\+?=" \
        -e "${AT}${DECL}([[:space:]]+[A-Za-z_][A-Za-z0-9_]*(\+?=[^[:space:]]*)?)*[[:space:]]+$1([[:space:]]|$)" \
        -e "${AT}printf[[:space:]]+(-[^[:space:]]+[[:space:]]+)*-v[[:space:]]*$1([[:space:]]|$)" \
        -e "${AT}(read|readarray|mapfile)[[:space:]](.*[[:space:]])?$1([[:space:]]|$)" \
        -e "(^|[^A-Za-z0-9_])$1\+?=[^[:space:]]*[[:space:]]+(${ASSIGN}[[:space:]]+)*([^[:space:]]*/)?git([[:space:]]|$)"
    }
    if assigns '(NONNA_MODE|NONNA_TEST_CMD|CLAUDE_PLUGIN_OPTION_[A-Za-z0-9_]+|GIT_CONFIG[A-Za-z0-9_]*)' \
      || { assigns '(HOME|XDG_CONFIG_HOME)' && runs_git; }; then
      recipe "refusing to set what her gates read: NONNA_MODE, NONNA_TEST_CMD, CLAUDE_PLUGIN_OPTION_*, GIT_CONFIG_*, or HOME for git."
    fi

    # Config on the command line (-c, --config-env) that switches her off or routes git around her.
    if printf '%s\n' "$segs" | grep -qiE "(^|[[:space:]{!=])([^[:space:]]*/)?git[[:space:]](.*[[:space:]])?(-c[[:space:]]+|--config-env[=[:space:]]+)${NKEY}"; then
      recipe "refusing to change Nonna's own git config."
    fi
    if printf '%s\n' "$segs" | grep -qiE "(^|[[:space:]{!=])([^[:space:]]*/)?git[[:space:]](.*[[:space:]])?(-c[[:space:]]+|--config-env[=[:space:]]+)${RKEY}"; then
      kitchen_door "refusing an include, alias, hooks path or forced refspec on the command line; the git hooks are the gate."
    fi

    # git config: a read is fine: --get*, --list, -l, the get/list subcommand, or one key (it has a
    # dot) with nothing after it, each after read-safe options only (git 2.45's --comment takes the
    # next word as its value, so a read flag after it is a comment). Every word after the key is a
    # value to git, an empty one ('') or one that looks like an option included, and git takes an
    # abbreviated action (--rem). A write to her keys, or to one that reroutes git, is refused.
    ROPT='[[:space:]]+(--(local|global|system|worktree|show-origin|show-scope|includes|no-includes|null|name-only|bool|int|bool-or-int|path|expiry-date)|-z|--type=[a-z-]+|--(file|blob)=[^[:space:]]+|(-f|--file|--blob|--type)[[:space:]]+[^-[:space:]][^[:space:]]*)'
    while IFS= read -r seg; do
      printf '%s' "$seg" | grep -qE "${GIT}config([[:space:]]|$)" || continue
      printf '%s' "$seg" | grep -qE "${GIT}config(${ROPT})*[[:space:]]+(--get[a-z-]*|--list|-l)([[:space:]=]|$)" && continue
      printf '%s' "$seg" | grep -qE "${GIT}config(${ROPT})*[[:space:]]+(get|list)([[:space:]]|$)" && continue
      printf '%s' "$seg" | sed -E "s/[[:space:]]+${RD}[0-9]*[<>]+([[:space:]]+${RD}[<>]+)*[[:space:]]+[^[:space:]]+//g" \
        | grep -qE "${GIT}config(${ROPT})*[[:space:]]+[^-[:space:]'][^[:space:]]*\.[^[:space:]]*[[:space:]]*$" && continue
      printf '%s' "$seg" | grep -qiE "(^|[[:space:]])${NKEY}" && recipe "refusing to change Nonna's own git config."
      if printf '%s' "$seg" | grep -qiE "(^|[[:space:]])(${RKEY}|(-e|--edit|edit)([[:space:]]|$))"; then
        kitchen_door "refusing a config change that can route git around her hooks (include, alias, core.hooksPath, a forced refspec, --edit)."
      fi
    done <<<"$segs"

    # The same files by hand: .git/config and the git hooks, as the target of a write. Reading them
    # (cat, grep, sed -n, awk, cp from) is fine. A copy's target is its last word once redirections
    # are set aside, or the directory given to -t / --target-directory.
    GITF='(^|[^A-Za-z0-9_.-])\.git/(hooks([/[:space:]]|$)|config([[:space:]]|$))'
    if printf '%s\n' "$segs" | grep -qE '>[[:space:]]*[^[:space:]]*\.git/(hooks|config)' \
      || printf '%s\n' "$segs" | grep -E "$GITF" \
      | grep -qE '(^|[[:space:]])(rm|unlink|chmod|chown|truncate|touch|shred|patch|ed|ex|vi|vim|nano|emacs|python3?|ruby|node|perl|tee|dd)([[:space:]]|$)|(^|[[:space:]])(sed|awk|gawk)[[:space:]](.*[[:space:]])?(-[A-Za-z]*i|--in-place)' \
      || printf '%s\n' "$segs" | grep -E '(^|[[:space:]])(cp|mv|ln|install|rsync)[[:space:]]' \
      | sed -E "s/[[:space:]]+${RD}[0-9]*[<>]+([[:space:]]+${RD}[<>]+)*[[:space:]]+[^[:space:]]+//g" \
      | grep -qE '(^|[^A-Za-z0-9_.-])\.git/(hooks(/[^[:space:]]*)?|config)[[:space:]]*$|(^|[[:space:]])(-[A-Za-z]*t[[:space:]]*|--ta[a-z-]*[=[:space:]]+)[^[:space:]]*\.git/(hooks|config)'; then
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

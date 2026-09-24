#!/usr/bin/env bash
# install.sh — Nonna in one command, for any agent host.
#
#   curl -fsSL https://raw.githubusercontent.com/kapadias/keel/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/kapadias/keel/main/install.sh | bash -s -- --host cursor
#
# Run it from the root of a git repository. It copies the harness (.claude/), the chosen hosts'
# rules files, a blank docs/STATUS.md and your stack's test-gate permissions, and wires the git
# pre-commit and pre-push hooks. It never overwrites a file or a git hook that already exists: it
# says so and moves on.
#
# Hosts: claude (default), agents (AGENTS.md: Codex, Zed, Amp, opencode, Roo, Jules, Junie…),
#        cursor, copilot, gemini, windsurf, cline, kiro, all. Several: --host cursor,agents
# Env:   NONNA_REF  branch or tag to install (default: main)
#        NONNA_SRC  install from a local checkout instead of cloning (used by the tests)
set -uo pipefail

REPO="https://github.com/kapadias/keel"
hosts="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --host) hosts="${2:-}"; shift 2 ;;
    --host=*) hosts="${1#--host=}"; shift ;;
    -h | --help) sed -n '2,16p' "$0" 2>/dev/null; exit 0 ;;
    *) echo "install.sh: unknown argument '$1' (try --host <name>)" >&2; exit 2 ;;
  esac
done
[ "$hosts" = all ] && hosts="claude,agents,cursor,copilot,gemini,windsurf,cline,kiro"

host_file() { # <host> -> the path its rules file lives at
  case "$1" in
    claude) echo "CLAUDE.md" ;;
    agents) echo "AGENTS.md" ;;
    cursor) echo ".cursor/rules/nonna.mdc" ;;
    copilot) echo ".github/copilot-instructions.md" ;;
    gemini) echo "GEMINI.md" ;;
    windsurf) echo ".windsurf/rules/nonna.md" ;;
    cline) echo ".clinerules/nonna.md" ;;
    kiro) echo ".kiro/steering/nonna.md" ;;
    *) return 1 ;;
  esac
}

IFS=',' read -r -a HOSTS <<<"$hosts"
[ "${#HOSTS[@]}" -gt 0 ] || { echo "install.sh: --host needs a value" >&2; exit 2; }
for h in "${HOSTS[@]}"; do
  host_file "$h" >/dev/null || { echo "install.sh: unknown host '$h' (claude, agents, cursor, copilot, gemini, windsurf, cline, kiro, all)" >&2; exit 2; }
done

top="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "✗ Nonna: I cook in a kitchen, not a car park. Run this from inside a git repository." >&2
  exit 1
}
cd "$top" || exit 1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [ -n "${NONNA_SRC:-}" ]; then
  src="$NONNA_SRC"
else
  git clone -q --depth 1 --branch "${NONNA_REF:-main}" "$REPO" "$work/src" 2>/dev/null || {
    echo "✗ Nonna: could not fetch $REPO@${NONNA_REF:-main}." >&2
    exit 1
  }
  src="$work/src"
fi
# Tracked files only: never a review verdict, a local setting or a stray file from the source.
mkdir -p "$work/pkg"
git -C "$src" ls-files -z -- .claude hosts stacks CLAUDE.md \
  | (cd "$src" && tar --null -T - -cf -) | tar -xf - -C "$work/pkg" || {
  echo "✗ Nonna: could not read the harness from $src." >&2
  exit 1
}
P="$work/pkg"

done_msgs=()
kept_msgs=()
put() { # <source> <dest>: copy unless dest exists
  if [ -e "$2" ]; then
    kept_msgs+=("$2")
    return 0
  fi
  mkdir -p "$(dirname "$2")" && cp -R "$1" "$2" && done_msgs+=("$2")
}

put "$P/.claude" ".claude"
chmod +x .claude/hooks/*.sh .claude/skills/*/scripts/*.sh 2>/dev/null || true

for h in "${HOSTS[@]}"; do
  f="$(host_file "$h")"
  if [ "$h" = claude ]; then put "$P/CLAUDE.md" "$f"; else put "$P/hosts/$f" "$f"; fi
done

if [ ! -e docs/STATUS.md ]; then
  mkdir -p docs
  printf '# STATUS\n\nWhat is true right now. The pre-push hook blocks a code push that leaves this file stale.\n\n## Current state\n\n## Recently changed\n\n## Next / open\n' > docs/STATUS.md
  done_msgs+=("docs/STATUS.md")
else
  kept_msgs+=("docs/STATUS.md")
fi

stack=""
[ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f setup.py ] && stack=python
[ -f package.json ] && stack=typescript
[ -f go.mod ] && stack=go
[ -f Cargo.toml ] && stack=rust
if [ -n "$stack" ] && [ -f "$P/stacks/$stack/settings.local.json" ]; then
  put "$P/stacks/$stack/settings.local.json" ".claude/settings.local.json"
fi

hooks_dir="$(git rev-parse --git-path hooks)"
warn_msgs=()
link_hook() { # <git hook name> <script under .claude/hooks>
  local dest="$hooks_dir/$1"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    grep -qs "$2" "$dest" || warn_msgs+=("$1: you already have a $1 hook — chain .claude/hooks/$2 from it, or my gates do not run")
    return 0
  fi
  if [ "$hooks_dir" = ".git/hooks" ]; then
    mkdir -p "$hooks_dir" && ln -s "../../.claude/hooks/$2" "$dest"
  else
    warn_msgs+=("$1: git hooks live in '$hooks_dir' (a hook manager?) — point its $1 at .claude/hooks/$2")
    return 0
  fi
  done_msgs+=("$dest -> .claude/hooks/$2")
}
link_hook pre-commit pre-commit.sh
link_hook pre-push require-status-sync.sh

echo "Nonna is in the kitchen."
for m in "${done_msgs[@]}"; do echo "  + $m"; done
for m in "${kept_msgs[@]}"; do echo "  = $m (already here, left alone)"; done
for m in "${warn_msgs[@]}"; do echo "  ! $m"; done
echo "No commits on main, no keys in files, and write it in docs/STATUS.md. Now go make a branch."
exit 0

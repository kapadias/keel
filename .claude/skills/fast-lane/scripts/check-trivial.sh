#!/usr/bin/env bash
# check-trivial.sh — deterministic fast-lane eligibility (the autonomy dial).
#
# Exit 0 iff the working delta vs BASE qualifies for the bounded fast lane:
#   • ≤ MAX_LINES changed lines across ≤ MAX_FILES files
#     (test/fixture/example paths and docs/STATUS.md do not count)
#   • no dependency manifest or lockfile touched
#   • no critical-surface path touched (built-ins below, extendable via
#     KEEL_CRITICAL_PATHS — a colon-separated list of shell globs)
#
# Anything else — including ANY ambiguity (not a repo, unresolvable base,
# binary change) — exits 1: the full loop applies. The script decides lane
# eligibility; prose cannot argue a change into the fast lane
# (rules/dev-process.md → Proportionality).
#
# Usage: check-trivial.sh [BASE_REF]
#        BASE_REF defaults to develop, then origin/develop, then HEAD~1.
set -uo pipefail

MAX_LINES=15
MAX_FILES=3

fail() {
  echo "✗ fast-lane: $1 — take the full loop (rules/dev-process.md)." >&2
  exit 1
}

git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository"

base="${1:-}"
if [ -z "$base" ]; then
  for c in develop origin/develop HEAD~1; do
    if git rev-parse --verify -q "$c" >/dev/null 2>&1; then
      base="$c"
      break
    fi
  done
fi
[ -n "$base" ] || fail "no usable base ref"
git rev-parse --verify -q "$base" >/dev/null 2>&1 || fail "base '$base' is unresolvable"
mb="$(git merge-base "$base" HEAD 2>/dev/null)" || fail "no merge base with '$base'"

is_test_path() {
  case "/$1" in
    */tests/* | */test/* | */fixtures/* | */fixture/* | */examples/* | */example/* | *.sample | *.sample.*) return 0 ;;
  esac
  return 1
}

is_lockfile() {
  case "$(basename "$1")" in
    package.json | package-lock.json | yarn.lock | pnpm-lock.yaml | bun.lockb | \
      pyproject.toml | poetry.lock | uv.lock | Pipfile | Pipfile.lock | requirements*.txt | \
      go.mod | go.sum | Cargo.toml | Cargo.lock | Gemfile | Gemfile.lock | \
      composer.json | composer.lock) return 0 ;;
  esac
  return 1
}

is_critical() {
  case "$1" in
    .claude/hooks/* | .claude/settings.json | .claude/skills/*/scripts/* | \
      .github/workflows/* | */migrations/* | migrations/*) return 0 ;;
  esac
  if [ -n "${KEEL_CRITICAL_PATHS:-}" ]; then
    local IFS=':'
    for g in $KEEL_CRITICAL_PATHS; do
      # shellcheck disable=SC2254
      case "$1" in $g) return 0 ;; esac
    done
  fi
  return 1
}

total_lines=0
total_files=0

classify() { # <path> [changed-line-count | "-" for binary]
  local f="$1" n="${2:-}"
  is_lockfile "$f" && fail "dependency manifest/lockfile touched ($f)"
  is_critical "$f" && fail "critical-surface path touched ($f)"
  [ "$f" = "docs/STATUS.md" ] && return 0
  is_test_path "$f" && return 0
  [ "$n" = "-" ] && fail "binary change ($f)"
  total_files=$((total_files + 1))
  total_lines=$((total_lines + n))
}

# Tracked delta: working tree vs merge-base (committed + staged + unstaged).
while IFS=$'\t' read -r add del f; do
  [ -n "$f" ] || continue
  if [ "$add" = "-" ] || [ "$del" = "-" ]; then
    classify "$f" "-"
  else
    classify "$f" "$((add + del))"
  fi
done <<EOF
$(git diff --numstat "$mb" 2>/dev/null)
EOF

# Untracked files count too — a brand-new source file is part of the delta.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  classify "$f" "$(wc -l <"$f" 2>/dev/null || echo "$((MAX_LINES + 1))")"
done <<EOF
$(git ls-files --others --exclude-standard 2>/dev/null)
EOF

[ "$total_files" -le "$MAX_FILES" ] || fail "$total_files files exceed the $MAX_FILES-file budget"
[ "$total_lines" -le "$MAX_LINES" ] || fail "$total_lines changed lines exceed the $MAX_LINES-line budget"

echo "✓ fast-lane: qualifies — $total_lines changed line(s) across $total_files file(s) vs $base." >&2
exit 0

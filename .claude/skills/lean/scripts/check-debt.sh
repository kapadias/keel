#!/usr/bin/env bash
# check-debt.sh — the debt-marker gate and ledger.
#
# A deliberate simplification with a known ceiling is marked in code with a comment of
# the form  <comment-prefix> debt: <ceiling>, <upgrade trigger>  — the text after the
# first comma is the trigger to revisit it. A marker with no trigger is "later means
# never" waiting to happen, so this script fails on it. The model proposes the corner;
# the script decides the marker is well-formed.
#
# Usage: check-debt.sh [--ledger] [--range <git-range>] [PATH...]
#   default   scan PATH... (or .) for markers; skips VCS/dependency/build dirs and *.md
#             (prose that quotes the convention is not debt)
#   --range   scan only lines ADDED by `git diff <git-range>` — a PR is gated on the debt
#             it introduces, not on debt someone else left
#   --ledger  print the grouped ledger to stdout (exit code unchanged)
# Exit: 0 every marker names a trigger · 1 at least one does not · 2 usage error,
#       --range outside a git repo, or an unresolvable range (fail closed).
# The comma is the only separator; a ceiling that needs a comma gets reworded. If real
# markers ever need a second separator, add it here and in the lean skill together.
set -uo pipefail

PATTERN='(#|//) ?debt:'
SKIP_DIRS=(.git node_modules dist build target vendor .venv venv __pycache__ coverage htmlcov)

usage() { sed -n '10,17p' "$0" >&2; exit 2; }

ledger=0; range=""; paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) ledger=1 ;;
    --range) [ $# -ge 2 ] || usage; range="$2"; shift ;;
    --range=*) range="${1#--range=}" ;;
    -h|--help) usage ;;
    --) shift; paths+=("$@"); break ;;
    -*) printf 'check-debt: unknown option %s\n' "$1" >&2; usage ;;
    *) paths+=("$1") ;;
  esac
  shift
done
[ ${#paths[@]} -gt 0 ] || paths=(.)

# Collect candidate lines as  path:line:text  — one source per mode.
collect() {
  if [ -n "$range" ]; then
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
      printf 'check-debt: --range needs a git repository\n' >&2; return 2; }
    local diff
    diff="$(git diff -U0 --no-prefix --no-renames "$range" -- . ':(exclude)*.md' 2>/dev/null)" || {
      printf 'check-debt: cannot resolve range %s\n' "$range" >&2; return 2; }
    printf '%s\n' "$diff" | awk -v pat="$PATTERN" '
      /^\+\+\+ / { file = substr($0, 5); next }
      /^--- /    { next }
      /^@@/      { if (match($0, /\+[0-9]+/)) ln = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
      /^\+/      { if (file != "/dev/null" && substr($0, 2) ~ pat) printf "%s:%d:%s\n", file, ln, substr($0, 2); ln++ }'
  else
    local args=()
    local d
    for d in "${SKIP_DIRS[@]}"; do args+=("--exclude-dir=$d"); done
    grep -rnIE "${args[@]}" --exclude='*.md' -- "$PATTERN" "${paths[@]}" 2>/dev/null | sed 's#^\./##'
  fi
  return 0
}

hits="$(collect)"; rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

# Classify: split the marker text at the first comma; both halves must be non-empty.
rows="$(printf '%s\n' "$hits" | awk -v pat="$PATTERN" -F: '
  NF < 3 { next }
  {
    file = $1; ln = $2; rest = substr($0, length(file) + length(ln) + 3)
    if (!match(rest, pat)) next
    text = substr(rest, RSTART + RLENGTH)
    i = index(text, ",")
    ceiling = (i > 0) ? substr(text, 1, i - 1) : text
    trigger = (i > 0) ? substr(text, i + 1) : ""
    gsub(/^[ \t]+|[ \t]+$/, "", ceiling); gsub(/^[ \t]+|[ \t]+$/, "", trigger)
    ok = (ceiling != "" && trigger != "") ? 1 : 0
    printf "%s\t%s\t%d\t%s\t%s\n", file, ln, ok, ceiling, trigger
  }' | sort -t "$(printf '\t')" -k1,1 -k2,2n)"

total=0; bad=0
if [ -n "$rows" ]; then
  total="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  bad="$(printf '%s\n' "$rows" | awk -F'\t' '$3 == 0' | wc -l | tr -d ' ')"
fi

if [ "$ledger" -eq 1 ]; then
  if [ "$total" -eq 0 ]; then
    echo "No debt markers. Clean ledger."
  else
    printf '%s\n' "$rows" | awk -F'\t' '
      $1 != last { print $1; last = $1 }
      { if ($3 == 1) printf "  L%s: %s — upgrade: %s\n", $2, $4, $5
        else          printf "  L%s: %s — no-trigger\n", $2, $4 }'
    printf '%s markers, %s with no trigger.\n' "$total" "$bad"
  fi
fi

if [ "$bad" -gt 0 ]; then
  printf '%s\n' "$rows" | awk -F'\t' '$3 == 0 { printf "✗ check-debt: %s:%s: no-trigger — %s\n", $1, $2, $4 }' >&2
  printf '✗ check-debt: %s marker(s), %s with no trigger — name the trigger after the comma.\n' "$total" "$bad" >&2
  exit 1
fi
printf '✓ check-debt: %s marker(s), 0 with no trigger.\n' "$total" >&2
exit 0

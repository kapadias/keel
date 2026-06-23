#!/usr/bin/env bash
# bisect.sh — guided `git bisect run` helper (see .claude/skills/debugging/SKILL.md, step 2).
#
# Answers the single most productive debugging question — "what changed since it last worked?" —
# in log2(n) steps. You supply a known-GOOD ref and a test command that exits 0 when the bug is
# ABSENT and non-zero when it is PRESENT; the script drives the bisect, prints the first bad
# commit, and always resets the bisect state cleanly (even on error or Ctrl-C).
#
# Usage:
#   bisect.sh <good-ref> <test-command...>
#
# Examples:
#   bisect.sh v1.4.0 pytest tests/test_orders.py::test_total
#   bisect.sh HEAD~50 'npm test -- --run orders'        # quote a command with shell syntax
#   bisect.sh abc1234 ./scripts/repro.sh                 # a deterministic repro script
#
# Contract for the test command (git bisect's convention):
#   exit 0   → this commit is GOOD (bug absent)
#   exit 125 → SKIP (cannot test this commit — e.g. it won't build)
#   1..127   → this commit is BAD (bug present)   [124/125/126/127 are reserved by git]
# Make the repro deterministic first (seed RNG, inject the clock); a flaky test mis-bisects.
set -euo pipefail

usage() {
  echo "usage: bisect.sh <good-ref> <test-command...>" >&2
  echo "  <good-ref>        a commit/tag/branch where the bug is ABSENT (the current HEAD is the bad end)" >&2
  echo "  <test-command...> a command that exits 0 when the bug is absent, non-zero when present" >&2
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

if [ "$#" -lt 2 ]; then
  usage
  exit 2
fi

good_ref="$1"
shift
# Remaining arguments form the test command, preserved as separate argv entries.
test_cmd=("$@")

# Must be inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "✗ bisect: not inside a git repository." >&2
  exit 2
}

# Validate the good ref resolves to a commit.
good_sha="$(git rev-parse --verify --quiet "${good_ref}^{commit}")" || {
  echo "✗ bisect: '$good_ref' is not a valid commit/ref." >&2
  exit 2
}

bad_sha="$(git rev-parse --verify HEAD)"
if [ "$good_sha" = "$bad_sha" ]; then
  echo "✗ bisect: good ref and HEAD are the same commit — nothing to bisect." >&2
  exit 2
fi

# Refuse to clobber an in-progress bisect.
if git bisect log >/dev/null 2>&1; then
  echo "✗ bisect: a bisect is already in progress. Run 'git bisect reset' first." >&2
  exit 2
fi

# Always leave the repo in a clean state — reset the bisect and restore the original HEAD.
start_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
cleanup() {
  git bisect reset >/dev/null 2>&1 || true
  if [ -n "${start_branch:-}" ] && [ "$start_branch" != "HEAD" ]; then
    git checkout --quiet "$start_branch" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

echo "ℹ bisect: bad=HEAD ($(git rev-parse --short "$bad_sha"))  good=$good_ref ($(git rev-parse --short "$good_sha"))"
echo "ℹ bisect: test command: ${test_cmd[*]}"

git bisect start
git bisect bad "$bad_sha"
git bisect good "$good_sha"

# `git bisect run` checks out each midpoint, runs the command, and classifies by exit code.
# We capture the run output to extract the culprit afterward.
run_log="$(mktemp)"
trap 'rm -f "$run_log"; cleanup' EXIT INT TERM

set +e
git bisect run "${test_cmd[@]}" | tee "$run_log"
run_status="${PIPESTATUS[0]}"
set -e

echo
if [ "$run_status" -ne 0 ]; then
  echo "✗ bisect: 'git bisect run' did not converge (exit $run_status)." >&2
  echo "  Common causes: the good ref is not actually good, the bug is flaky, or the test errors" >&2
  echo "  for an unrelated reason (use exit 125 in the test command to SKIP untestable commits)." >&2
  exit "$run_status"
fi

# git prints a line like: "<sha> is the first bad commit"
culprit="$(grep -Eo '^[0-9a-f]{7,40} is the first bad commit' "$run_log" | head -n1 | awk '{print $1}')"
if [ -z "$culprit" ]; then
  # Fall back to git's own record of where it stopped.
  culprit="$(git rev-parse --verify --quiet refs/bisect/bad || true)"
fi

if [ -n "$culprit" ]; then
  echo "════════════════════════════════════════════════════════════════"
  echo "First bad commit: $culprit"
  echo "────────────────────────────────────────────────────────────────"
  git --no-pager show --no-patch --format='  %h  %an  %ad%n  %s' "$culprit"
  echo "════════════════════════════════════════════════════════════════"
  echo "Next: read this commit's diff, form a one-sentence root-cause hypothesis (SKILL.md step 3),"
  echo "then fix the cause minimally and leave a regression test behind."
else
  echo "✗ bisect: could not identify the first bad commit from the run output." >&2
  exit 1
fi

# cleanup runs on EXIT: resets bisect and restores the original branch.

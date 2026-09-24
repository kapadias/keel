#!/usr/bin/env bash
# Pre-push git hook — the Definition of Done (rules/sync.md): a push that changes
# CODE must also update docs/STATUS.md, and must not introduce a secret.
#
# Auto-installed by .claude/hooks/session-start.sh, or manually:
#   ln -sf ../../.claude/hooks/require-status-sync.sh .git/hooks/pre-push
# Bypass (only when you truly changed no code): git push --no-verify
set -uo pipefail
# Resolve through symlinks: this hook is installed AS a .git/hooks/pre-push
# symlink, so BASH_SOURCE points at the link, not the real script beside its lib/.
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
  link="$(readlink "$self")"
  case "$link" in
    /*) self="$link" ;;
    *) self="$(dirname "$self")/$link" ;;
  esac
done
here="$(cd "$(dirname "$self")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/secret-patterns.sh"

# What is being pushed. git hands the hook "<local ref> <local sha> <remote ref> <remote sha>" lines
# on stdin; a new branch has an all-zero remote sha, so its range starts where it left the base
# branch. Run by hand (no stdin), fall back to the upstream, then to the base branch.
ZERO=0000000000000000000000000000000000000000
base_of() { # <sha>: where it forked from the default branch, else the empty tree (everything)
  local b
  for b in origin/HEAD origin/develop origin/main origin/master develop main master; do
    [ "$(git rev-parse --verify --quiet "$b^{commit}")" = "$(git rev-parse --verify --quiet "$1^{commit}")" ] && continue
    git merge-base "$b" "$1" 2>/dev/null && return 0
  done
  git hash-object -t tree /dev/null
}
ranges=()
pushed_tips=()
if [ ! -t 0 ]; then
  while read -r _lref lsha _rref rsha; do
    [ -n "${lsha:-}" ] && [ "$lsha" != "$ZERO" ] || continue # a delete pushes no code
    pushed_tips+=("$lsha")
    if [ "$rsha" = "$ZERO" ] || ! git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      ranges+=("$(base_of "$lsha")..$lsha")
    else
      ranges+=("$rsha..$lsha")
    fi
  done
fi
if [ "${#ranges[@]}" -eq 0 ] && [ "${#pushed_tips[@]}" -eq 0 ]; then
  upstream="origin/$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  if git rev-parse --verify --quiet "$upstream" >/dev/null; then
    ranges=("$upstream..HEAD")
  else
    ranges=("$(base_of HEAD)..HEAD")
  fi
  pushed_tips=("$(git rev-parse HEAD 2>/dev/null)")
fi
[ "${#ranges[@]}" -gt 0 ] || exit 0

changed="$(for r in "${ranges[@]}"; do git diff --name-only "${r%%..*}" "${r##*..}" 2>/dev/null; done | sort -u)"
[ -n "$changed" ] || exit 0

# CODE = everything EXCEPT docs/ and a few top-level meta files. NOTE: .claude/**
# IS code (the harness is a tracked mirror, rules/sync.md) even though it is
# markdown — so harness changes also require a STATUS update.
code_touched="$(printf '%s\n' "$changed" | grep -Ev '^(docs/|LICENSE$|\.gitignore$|[^/]*\.md$)' || true)"
status_touched="$(printf '%s\n' "$changed" | grep -E '^docs/STATUS\.md$' || true)"

fail=0
if [ -n "$code_touched" ] && [ -z "$status_touched" ]; then
  {
    echo "✗ Nonna: you cooked, now write it in the recipe book. (Definition of Done: code changed but docs/STATUS.md was not updated.)"
    echo "  Update docs/STATUS.md (rules/sync.md), or 'git push --no-verify' if truly N/A."
  } >&2
  fail=1
fi

# Secret scan over added lines, per file. Unlike the write-time gate, there is
# NO fixture-path exemption here: a push is outward-facing, and a realistic-
# looking credential under tests/ leaks exactly like one under src/. Fixtures
# must use placeholder-classed values (AKIAIOSFODNN7EXAMPLE, XXXX, CHANGEME, …)
# — those are value-exempt in lib/secret-patterns.sh.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  added="$(for r in "${ranges[@]}"; do git --literal-pathspecs diff --text "${r%%..*}" "${r##*..}" -- "$f" 2>/dev/null; done | grep -aE '^\+' | grep -avE '^\+\+\+' || true)"
  [ -n "$added" ] || continue
  if class="$(printf '%s' "$added" | nonna_scan_secrets)"; then
    {
      echo "✗ Push blocked: ${f} introduces what looks like a ${class}."
      echo "  Remove it and ROTATE the secret (rules/safety.md). Never push secrets."
    } >&2
    fail=1
  fi
done <<EOF
$changed
EOF

# "Done" means the suite passes: a code push runs the project's own tests (lib/tests.sh). No test
# command (plugin installs need NONNA_TEST_CMD, or NONNA_TEST_CMD="") means this check does not
# apply. The suite runs in the working tree, so it must BE what is pushed: HEAD, with no uncommitted
# change to a tracked file that could hide a broken commit.
if [ -n "$code_touched" ] && [ -f "$here/lib/tests.sh" ]; then
  # shellcheck source=/dev/null
  . "$here/lib/tests.sh"
  cmd="$(nonna_test_cmd)"
  if [ -n "$cmd" ]; then
    head="$(git rev-parse HEAD 2>/dev/null)"
    foreign=""
    for t in "${pushed_tips[@]}"; do [ "$t" = "$head" ] || foreign=1; done
    if [ -n "$foreign" ] || ! git diff --quiet HEAD -- 2>/dev/null; then
      {
        echo "✗ Nonna: I taste what you serve, not what is still on the stove. (pre-push: the tests run in the working tree, which is not what you are pushing.)"
        echo "  commit or stash your changes, and push the branch you have checked out."
      } >&2
      fail=1
    else
      nonna_run_tests "$cmd"
      rc=$?
      if [ "$rc" = 124 ]; then
        {
          echo "✗ Nonna: the tests never finished, so they did not say yes. (pre-push: \`$cmd\` timed out after ${NONNA_TEST_TIMEOUT:-600}s.)"
          echo "  Raise NONNA_TEST_TIMEOUT, or set NONNA_TEST_CMD to a faster suite."
        } >&2
        fail=1
      elif [ "$rc" != 0 ]; then
        {
          echo "✗ Nonna: you said done; the tests say no. (pre-push: \`$cmd\` failed.)"
          printf '%s\n' "${NONNA_TEST_TAIL:-}" | sed 's/^/    /'
          echo "  Fix it, or set NONNA_TEST_CMD if that is not your test command."
        } >&2
        fail=1
      fi
    fi
  fi
fi

exit "$fail"

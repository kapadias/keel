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

# What is being pushed: every commit the remote does not have yet, never "since a local branch" (a
# commit that only exists locally, say a --no-verify root commit on main, is pushed too). git passes
# the remote as $1 and "<local ref> <local sha> <remote ref> <remote sha>" lines on stdin. Run by
# hand (no stdin): HEAD's commits that no remote has.
ZERO=0000000000000000000000000000000000000000
remote="${1:-}"
not_remote=(--remotes)
if [ -n "$remote" ] && git config --get "remote.$remote.url" >/dev/null 2>&1; then
  not_remote=("--remotes=$remote")
fi
tips=()      # pushed commits (tags peeled)
branch_tips=() # pushed branch commits: what the test gate must vouch for
saw_line=""
if [ ! -t 0 ]; then
  while read -r lref lsha _rref rsha; do
    [ -n "${lsha:-}" ] || continue
    saw_line=1
    [ "$lsha" != "$ZERO" ] || continue # a delete pushes no code
    c="$(git rev-parse --verify --quiet "$lsha^{commit}")" || continue # a tag on a tree or blob
    tips+=("$c")
    case "$lref" in refs/tags/*) ;; *) branch_tips+=("$c") ;; esac
    if [ "${rsha:-$ZERO}" != "$ZERO" ] && git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      not_remote+=("^$rsha")
    fi
  done
fi
if [ -z "$saw_line" ]; then
  c="$(git rev-parse --verify --quiet HEAD)" || exit 0
  tips=("$c")
  branch_tips=("$c")
fi
[ "${#tips[@]}" -gt 0 ] || exit 0 # deletes only
revs=("${tips[@]}" --not "${not_remote[@]}")
new_commits="$(git rev-list "${revs[@]}" 2>/dev/null)" || {
  echo "✗ Nonna: I could not tell what you are pushing, so I cannot vouch for it. (pre-push: git rev-list failed.)" >&2
  exit 1
}
[ -n "$new_commits" ] || exit 0
# Every commit's own diff, so a key added then removed inside the push is still seen. Flags keep
# user config (colour, external diff, textconv, quoted names) from hiding a line.
LOG=(git --literal-pathspecs -c core.quotePath=false log --format= --no-color --no-ext-diff --no-textconv --text --no-renames)

changed="$("${LOG[@]}" --name-only -z "${revs[@]}" | tr '\0' '\n' | sort -u)"
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
while IFS= read -r -d '' f; do
  added="$("${LOG[@]}" -p -U0 "${revs[@]}" -- "$f" 2>/dev/null | grep -aE '^\+' | grep -avE '^\+\+\+ ' || true)"
  [ -n "$added" ] || continue
  if class="$(printf '%s' "$added" | nonna_scan_secrets)"; then
    {
      echo "✗ Push blocked: ${f} introduces what looks like a ${class}."
      echo "  Remove it and ROTATE the secret (rules/safety.md). Never push secrets."
    } >&2
    fail=1
  fi
done < <("${LOG[@]}" --name-only -z --diff-filter=ACMRT "${revs[@]}" | sort -zu)

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
    at_head=""
    for t in ${branch_tips[@]+"${branch_tips[@]}"}; do
      if [ "$t" = "$head" ]; then at_head=1; else
        echo "! Nonna: $t is not checked out, so its tests did not run here. Push it from its own checkout." >&2
      fi
    done
    if [ -z "$at_head" ]; then
      : # tags, or branches that are not checked out: nothing here to taste
    elif [ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]; then
      {
        echo "✗ Nonna: I taste what you serve, not what is still on the stove. (pre-push: the tests run in the working tree, and it differs from HEAD.)"
        echo "  commit or stash your changes (untracked files too: a forgotten git add passes here and breaks there)."
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

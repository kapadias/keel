#!/usr/bin/env bash
# Stop — do not let a turn end declaring work done while docs/STATUS.md is stale.
#
# Nonna already blocks this at push time (require-status-sync.sh). That is too
# late: the agent has usually already said "done" several turns earlier, and the
# five mirrors have been out of agreement the whole time (rules/sync.md). This
# pulls the same check to the end of every turn that actually changed tracked
# code, so drift is caught where it starts.
#
# Deliberately narrow. It fires ONLY when tracked, non-doc files are modified
# and docs/STATUS.md is untouched. Reading, planning, running tests, and
# doc-only edits all end freely. Claude Code overrides a Stop hook after 8
# consecutive blocks, so this can annoy but cannot deadlock.
#
# Fails OPEN by design, unlike Nonna's write-time gates: a Stop hook that errors
# on a machine without git would wedge every turn in the session, and the
# blocking pre-push gate still backstops the actual push (ADR-0004's asymmetry —
# this one is a convenience gate, not the gate).
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# What changed, ignoring the surfaces that are not "code" for DoD purposes:
# docs/ (STATUS lives there), and .claude/reviews/ (transient, git-ignored).
# Order matters: drop untracked entries while the porcelain status column is
# still present, THEN strip it. Stripping first erases the '??' marker and every
# scratch file would read as a tracked change.
dirty="$(git status --porcelain 2>/dev/null \
  | grep -vE '^\?\?' \
  | awk '{ $1=""; sub(/^ +/,""); print }' \
  | grep -vE '^(docs/|\.claude/reviews/)' || true)"
[ -n "$dirty" ] || exit 0

reason=""

# "Done" means the suite passes. Run the project's own tests when code changed; block once on red.
# On the second stop (stop_hook_active) let it through: an agent that cannot fix it must say so,
# not loop. No test command (see lib/tests.sh: plugin installs need NONNA_TEST_CMD) means this check
# does not apply. A green run is remembered per tree and command, so an idle turn end costs nothing;
# a suite slower than the Stop budget is not red, and the pre-push gate still runs it in full.
if ! printf '%s' "$payload" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' \
  && [ -f "$here/lib/tests.sh" ]; then
  # shellcheck source=/dev/null
  . "$here/lib/tests.sh"
  cmd="$(nonna_test_cmd)"
  if [ -n "$cmd" ]; then
    green_file="$(git rev-parse --git-path nonna-green 2>/dev/null || true)"
    idx="$(mktemp 2>/dev/null || true)"
    key=""
    if [ -n "$idx" ] && cp "$(git rev-parse --git-path index)" "$idx" 2>/dev/null \
      && tree="$(GIT_INDEX_FILE="$idx" git add -A . >/dev/null 2>&1 && GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null)"; then
      key="$(printf '%s\n%s' "$tree" "$cmd" | git hash-object --stdin 2>/dev/null || true)"
    fi
    [ -n "$idx" ] && rm -f "$idx"
    if [ -n "$key" ] && [ -n "$green_file" ] && [ "$(cat "$green_file" 2>/dev/null)" = "$key" ]; then
      : # this exact tree already passed this exact command
    else
      NONNA_TEST_TIMEOUT="${NONNA_TEST_TIMEOUT:-240}" nonna_run_tests "$cmd"
      rc=$?
      if [ "$rc" = 0 ]; then
        [ -n "$key" ] && [ -n "$green_file" ] && printf '%s\n' "$key" > "$green_file" 2>/dev/null
      elif [ "$rc" != 124 ]; then
        tail_line="$(printf '%s' "${NONNA_TEST_TAIL:-}" | tr '\n' '|' | cut -c1-600)"
        reason="Nonna: you said done; the tests say no. \`$cmd\` failed: ${tail_line} Fix it and run the full suite, or tell the user plainly that it is not done and why. "
      fi
    fi
  fi
fi

# Already synced? Covers staged, unstaged, and committed-this-branch.
if ! git status --porcelain -- docs/STATUS.md 2>/dev/null | grep -q .; then
  count="$(printf '%s\n' "$dirty" | grep -c . || true)"
  reason="${reason}Nonna: write it in the recipe book before you leave the table. Definition of Done: ${count} tracked file(s) changed but docs/STATUS.md is untouched. Update it with what changed and the current state (rules/sync.md), or say explicitly why this turn is not a completed unit of work. The pre-push hook will block the push otherwise."
fi
[ -n "$reason" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg r "$reason" '{decision: "block", reason: $r}'
else
  # No jq: printable ASCII only, then escape the two characters JSON strings cannot hold raw.
  reason="$(printf '%s' "$reason" | LC_ALL=C tr -c '[:print:]' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
fi
exit 0

#!/usr/bin/env bash
# Stop — do not let a turn end declaring work done while docs/STATUS.md is stale.
#
# Keel already blocks this at push time (require-status-sync.sh). That is too
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
# Fails OPEN by design, unlike Keel's write-time gates: a Stop hook that errors
# on a machine without git would wedge every turn in the session, and the
# blocking pre-push gate still backstops the actual push (ADR-0004's asymmetry —
# this one is a convenience gate, not the gate).
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Already synced? Nothing to say. Covers staged, unstaged, and committed-this-branch.
git status --porcelain -- docs/STATUS.md 2>/dev/null | grep -q . && exit 0

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

count="$(printf '%s\n' "$dirty" | grep -c . || true)"
reason="Definition of Done: ${count} tracked file(s) changed but docs/STATUS.md is untouched. Update it with what changed and the current state (rules/sync.md), or say explicitly why this turn is not a completed unit of work. The pre-push hook will block the push otherwise."

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg r "$reason" '{decision: "block", reason: $r}'
else
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
fi
exit 0

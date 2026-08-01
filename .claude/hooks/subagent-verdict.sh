#!/usr/bin/env bash
# SubagentStop (code-reviewer | security-reviewer) — validate the verdict where
# it is produced, not several steps later.
#
# ADR-0005 makes a machine-checkable JSON verdict the thing that decides merges,
# and check-review.sh the decider. But that contract only binds if /review
# remembers to write the verdict file and run the checker. A reviewer that
# returns prose, an unparseable block, or two blocks currently sails past this
# boundary and is only caught downstream — if at all.
#
# This runs the SAME check-review.sh against the reviewer's own output, at the
# moment it finishes. No new parser, no second source of truth for the schema.
#
# Fails OPEN when it cannot read the transcript or locate the checker: this is a
# defence-in-depth layer, and /review + /ship still run the real gate. It fails
# CLOSED on what it can actually judge — output that is present but malformed.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0   # structured read required; backstopped by /review

transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Locate the decider in either install mode (ADR-0007).
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
checker=""
for cand in \
  "${CLAUDE_PLUGIN_ROOT:-}/skills/code-review/scripts/check-review.sh" \
  "$root/.claude/skills/code-review/scripts/check-review.sh"; do
  [ -n "$cand" ] && [ -f "$cand" ] && { checker="$cand"; break; }
done
[ -n "$checker" ] || exit 0

# Last assistant text in the subagent transcript = what it returned.
last="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]?
                 | select(.type=="text") | .text] | last // empty' \
        "$transcript" 2>/dev/null)"
[ -n "$last" ] || exit 0

out="$(printf '%s' "$last" | bash "$checker" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && exit 0

reason="Reviewer verdict rejected by check-review.sh (exit ${rc}): ${out}. ADR-0005: the reviewer must emit exactly one fenced json block with a verdict and findings[]. Re-run the reviewer and have it emit the contract — do not hand-write or paraphrase the verdict."
jq -cn --arg r "$reason" '{decision: "block", reason: $r}'
exit 0

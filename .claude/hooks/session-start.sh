#!/usr/bin/env bash
# SessionStart — make the harness self-installing and situational.
#   1. Idempotently install the Definition-of-Done pre-push hook, so the gate
#      runs on a fresh clone without a manual symlink (closes the "never wired"
#      gap that made the DoD gate inert in v0.1).
#   2. Detect the project's toolchain.
#   3. Inject a short additionalContext note: the gates are live, and the likely
#      test command.
# Best-effort: always exits 0; a SessionStart failure must never wedge a session.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0

# 0. Resolve the harness root. A standalone checkout has .claude/ in the repo; a
#    plugin install has the harness at ${CLAUDE_PLUGIN_ROOT} and NOTHING in the
#    repo. Guarding only on the project-local path made a plugin install skip the
#    DoD gate in silence — a gate that is off without saying so is precisely the
#    unwired-gate defect ADR-0004 exists to prevent.
keel_root=""
keel_link=""   # symlink target for the pre-push hook: relative in-repo, absolute otherwise
if [ -f ".claude/hooks/require-status-sync.sh" ]; then
  keel_root="$(cd .claude 2>/dev/null && pwd)"
  keel_link="../../.claude/hooks/require-status-sync.sh"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/require-status-sync.sh" ]; then
  keel_root="${CLAUDE_PLUGIN_ROOT}"
  keel_link="${CLAUDE_PLUGIN_ROOT}/hooks/require-status-sync.sh"
fi

# 1. Install the pre-push hook if absent and this is a git checkout. Guard on the
#    source EXISTING — never create a dangling symlink, which git would try to
#    exec and fail, wedging every push.
dod_warn=""
if [ ! -d .git ]; then
  : # not a git checkout — nothing to wire, nothing to warn about
elif [ -z "$keel_root" ]; then
  dod_warn=" WARNING: Keel's pre-push hook could not be located (no .claude/hooks/ in this project and CLAUDE_PLUGIN_ROOT unset or incomplete) — Definition of Done is NOT enforced."
elif [ ! -e .git/hooks/pre-push ] && [ ! -L .git/hooks/pre-push ]; then
  ln -sf "$keel_link" .git/hooks/pre-push 2>/dev/null \
    || cp "$keel_root/hooks/require-status-sync.sh" .git/hooks/pre-push 2>/dev/null \
    || true
  chmod +x "$keel_root/hooks/require-status-sync.sh" 2>/dev/null || true
  # Never assume the write landed — an unwritable .git/hooks must not pass silently.
  [ -e .git/hooks/pre-push ] \
    || dod_warn=" WARNING: could not install Keel's pre-push hook into .git/hooks — Definition of Done is NOT enforced."
elif ! grep -qs 'require-status-sync' .git/hooks/pre-push; then
  # A foreign pre-push hook is installed. Never overwrite it (destructive) —
  # but going silent would disable the DoD gate without anyone knowing.
  dod_warn=" WARNING: .git/hooks/pre-push exists and is not Keel's DoD hook — Definition of Done is NOT enforced; chain ${keel_root}/hooks/require-status-sync.sh from your hook manually."
fi

# 2. Detect toolchain.
stack=""
testcmd=""
[ -f package.json ] && { stack="$stack node"; testcmd="npm test"; }
{ [ -f pyproject.toml ] || [ -f setup.cfg ]; } && { stack="$stack python"; testcmd="pytest"; }
[ -f go.mod ] && { stack="$stack go"; testcmd="go test ./..."; }
[ -f Cargo.toml ] && { stack="$stack rust"; testcmd="cargo test"; }
stack="$(printf '%s' "$stack" | sed 's/^ //')"
[ -n "$stack" ] || stack="undetected"

# 3. Emit additionalContext (JSON on stdout; exit 0).
msg="Keel harness active. Gates live: branch-guard (no commits/pushes to main/master/develop, no force pushes), secret-scan on writes and Bash secret reads, Definition-of-Done pre-push (docs/STATUS.md). Detected stack: ${stack}.${dod_warn}"
# Announce where the harness actually lives. Commands invoke gate scripts under
# skills/*/scripts/; that path differs between a standalone checkout and a plugin
# install, and the model cannot infer it. Resolving it here — in the one process
# that has CLAUDE_PLUGIN_ROOT exported — keeps the model out of the guess.
[ -n "$keel_root" ] && msg="${msg} Harness root: ${keel_root} — gate scripts live at \${KEEL}/skills/<skill>/scripts/, e.g. ${keel_root}/skills/code-review/scripts/check-review.sh."
[ -n "$testcmd" ] && msg="${msg} Likely test gate: '${testcmd}' — wire /test to your gate (see stacks/)."

# 4. Plugin install: carry the constitution in. Claude Code's plugin schema has
#    no `rules` component (ADR-0007), so .claude/rules/ never loads for a plugin
#    user — they would get every agent, skill and command but none of the policy
#    that governs them. additionalContext is the only channel that reaches them.
#    Only 00-core.md rides it: budgeted under 9,000 chars against the 10,000 cap,
#    because an overrun truncates silently rather than erroring.
#    A standalone checkout already loads rules/ natively — do not double-pay.
if [ ! -f ".claude/rules/00-core.md" ] && [ -n "$keel_root" ] && [ -f "$keel_root/rules/00-core.md" ]; then
  core="$(cat "$keel_root/rules/00-core.md" 2>/dev/null)"
  if [ -n "$core" ]; then
    msg="${msg}

Keel's operating rules are NOT loaded in this install (plugin installs cannot carry .claude/rules/ — see ADR-0007). The constitution follows; the full rules are readable at ${keel_root}/rules/.

${core}"
  fi
fi

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg c "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
else
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
fi
exit 0

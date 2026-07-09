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

# 1. Install the pre-push hook if absent and this is a git checkout. Guard on the
#    source EXISTING — never create a dangling symlink, which git would try to
#    exec and fail, wedging every push.
src=".claude/hooks/require-status-sync.sh"
dod_warn=""
if [ -d .git ] && [ -f "$src" ]; then
  if [ ! -e .git/hooks/pre-push ] && [ ! -L .git/hooks/pre-push ]; then
    ln -sf "../../$src" .git/hooks/pre-push 2>/dev/null \
      || cp "$src" .git/hooks/pre-push 2>/dev/null \
      || true
    chmod +x "$src" 2>/dev/null || true
  elif ! grep -qs 'require-status-sync' .git/hooks/pre-push; then
    # A foreign pre-push hook is installed. Never overwrite it (destructive) —
    # but going silent would disable the DoD gate without anyone knowing.
    dod_warn=" WARNING: .git/hooks/pre-push exists and is not Keel's DoD hook — Definition of Done is NOT enforced; chain .claude/hooks/require-status-sync.sh from your hook manually."
  fi
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
msg="Keel harness active. Gates live: branch-guard (no commits/pushes to main/master/develop), secret-scan on writes, Definition-of-Done pre-push (docs/STATUS.md). Detected stack: ${stack}.${dod_warn}"
[ -n "$testcmd" ] && msg="${msg} Likely test gate: '${testcmd}' — wire /test to your gate (see stacks/)."

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg c "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
else
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
fi
exit 0

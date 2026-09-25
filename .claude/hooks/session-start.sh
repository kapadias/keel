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
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/core.sh"
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
[ "$(nonna_mode)" = off ] && exit 0 # off means off: nothing enforced, nothing said

# 0. Resolve the harness root. A standalone checkout has .claude/ in the repo; a
#    plugin install has the harness at ${CLAUDE_PLUGIN_ROOT} and NOTHING in the
#    repo. Guarding only on the project-local path made a plugin install skip the
#    DoD gate in silence — a gate that is off without saying so is precisely the
#    unwired-gate defect ADR-0004 exists to prevent.
#    Resolution lives in lib/core.sh, shared with subagent-start.sh.
nonna_root="$(nonna_harness_root)"
nonna_link=""   # symlink target for the pre-push hook: relative in-repo, absolute otherwise
if [ -f ".claude/hooks/require-status-sync.sh" ]; then
  nonna_link="../../.claude/hooks/require-status-sync.sh"
elif [ -n "$nonna_root" ]; then
  nonna_link="${nonna_root}/hooks/require-status-sync.sh"
fi

# 1. Install the pre-push hook if absent and this is a git checkout. Guard on the
#    source EXISTING — never create a dangling symlink, which git would try to
#    exec and fail, wedging every push.
dod_warn=""
if [ ! -d .git ]; then
  : # not a git checkout — nothing to wire, nothing to warn about
elif [ -z "$nonna_root" ]; then
  dod_warn=" WARNING: Nonna's pre-push hook could not be located (no .claude/hooks/ in this project and CLAUDE_PLUGIN_ROOT unset or incomplete) — Definition of Done is NOT enforced."
elif [ ! -e .git/hooks/pre-push ] && [ ! -L .git/hooks/pre-push ]; then
  ln -sf "$nonna_link" .git/hooks/pre-push 2>/dev/null \
    || cp "$nonna_root/hooks/require-status-sync.sh" .git/hooks/pre-push 2>/dev/null \
    || true
  chmod +x "$nonna_root/hooks/require-status-sync.sh" 2>/dev/null || true
  # Never assume the write landed — an unwritable .git/hooks must not pass silently.
  [ -e .git/hooks/pre-push ] \
    || dod_warn=" WARNING: could not install Nonna's pre-push hook into .git/hooks — Definition of Done is NOT enforced."
elif ! grep -qs 'require-status-sync' .git/hooks/pre-push; then
  # A foreign pre-push hook is installed. Never overwrite it (destructive) —
  # but going silent would disable the DoD gate without anyone knowing.
  dod_warn=" WARNING: .git/hooks/pre-push exists and is not Nonna's DoD hook — Definition of Done is NOT enforced; chain ${nonna_root}/hooks/require-status-sync.sh from your hook manually."
fi

# 2. Plugin install: record what the git hooks cannot read from the plugin's options, the first time
#    Nonna meets this repo: the mode, and (when the run_tests option allows it, the default) the test
#    command detection finds. Both go into the repo's own git config, which is never committed and
#    never cloned, so a hostile repo cannot plant either. Nothing already set is overwritten: not a
#    mode the user chose, not a command they set, not an empty one (the gate turned off).
if [ ! -f .claude/hooks/lib/tests.sh ] && [ -n "$nonna_root" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  git config --get nonna.mode >/dev/null 2>&1 || git config nonna.mode "$(nonna_mode)" 2>/dev/null || true
  case "${CLAUDE_PLUGIN_OPTION_RUN_TESTS:-true}" in
    false | False | FALSE | 0 | no | off) : ;;
    *)
      if ! git config --get nonna.testCmd >/dev/null 2>&1 && [ -f "$nonna_root/hooks/lib/tests.sh" ]; then
        # shellcheck source=/dev/null
        . "$nonna_root/hooks/lib/tests.sh"
        detected="$(nonna_detect_test_cmd)"
        [ -z "$detected" ] || git config nonna.testCmd "$detected" 2>/dev/null || true
      fi
      ;;
  esac
fi
gate=""
if [ -n "$nonna_root" ] && [ -f "$nonna_root/hooks/lib/tests.sh" ]; then
  # shellcheck source=/dev/null
  . "$nonna_root/hooks/lib/tests.sh"
  gate="$(nonna_test_cmd)"
fi

# 3. Detect toolchain.
stack=""
[ -f package.json ] && stack="$stack node"
{ [ -f pyproject.toml ] || [ -f setup.cfg ]; } && stack="$stack python"
[ -f go.mod ] && stack="$stack go"
[ -f Cargo.toml ] && stack="$stack rust"
stack="$(printf '%s' "$stack" | sed 's/^ //')"
[ -n "$stack" ] || stack="undetected"

# 4. Emit additionalContext (JSON on stdout; exit 0).
msg="Nonna harness active. Gates live: branch-guard (no commits/pushes to main/master/develop, no force pushes), secret-scan on writes and Bash secret reads, Definition-of-Done pre-push (docs/STATUS.md). Detected stack: ${stack}.${dod_warn}"
# Announce where the harness actually lives. Commands invoke gate scripts under
# skills/*/scripts/; that path differs between a standalone checkout and a plugin
# install, and the model cannot infer it. Resolving it here — in the one process
# that has CLAUDE_PLUGIN_ROOT exported — keeps the model out of the guess.
[ -n "$nonna_root" ] && msg="${msg} Harness root: ${nonna_root} — gate scripts live at \${NONNA}/skills/<skill>/scripts/, e.g. ${nonna_root}/skills/code-review/scripts/check-review.sh."
if [ -n "$gate" ]; then
  msg="${msg} Test gate: ${gate} runs before a turn that changed code can end, and before a push; a red suite blocks."
else
  msg="${msg} Test gate: off, no test command found here. The user can set one: git config nonna.testCmd '<command>'."
fi

# 5. Plugin install: carry the constitution in (nonna_core_carrier, lib/core.sh —
#    the same carrier subagent-start.sh uses, so parent and subagents agree).
core="$(nonna_core_carrier)"
[ -n "$core" ] && msg="${msg}

${core}"

nonna_emit_context SessionStart "$msg"
exit 0

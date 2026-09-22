# shellcheck shell=bash
# Sourced helper — where the harness lives, and how the constitution travels.
# Shared by session-start.sh (parent session) and subagent-start.sh (every
# subagent), so the two carriers cannot drift apart (ADR-0007, ADR-0008).

# keel_harness_root
#   Prints the harness root: the project's own .claude/ in a standalone checkout,
#   ${CLAUDE_PLUGIN_ROOT} under a plugin install, nothing when neither is found.
#   Runs from the project directory.
keel_harness_root() {
  if [ -f ".claude/hooks/require-status-sync.sh" ]; then
    (cd .claude 2>/dev/null && pwd)
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/require-status-sync.sh" ]; then
    printf '%s' "${CLAUDE_PLUGIN_ROOT}"
  fi
}

# keel_core_carrier
#   Plugin install: Claude Code's plugin schema has no `rules` component, so
#   .claude/rules/ never loads for a plugin user — they would get every agent,
#   skill and command but none of the policy that governs them. additionalContext
#   is the only channel that reaches them, and only 00-core.md rides it: budgeted
#   under 9,000 chars against the 10,000 cap, because an overrun truncates silently.
#   A standalone checkout already loads rules/ natively — print nothing, never
#   double-pay. Runs from the project directory.
keel_core_carrier() {
  local root core
  [ -f ".claude/rules/00-core.md" ] && return 0
  root="$(keel_harness_root)"
  [ -n "$root" ] && [ -f "$root/rules/00-core.md" ] || return 0
  core="$(cat "$root/rules/00-core.md" 2>/dev/null)"
  [ -n "$core" ] || return 0
  printf '%s\n\n%s\n' \
    "Keel's operating rules are NOT loaded in this install (plugin installs cannot carry .claude/rules/ — see ADR-0007). The constitution follows; the full rules are readable at ${root}/rules/." \
    "$core"
}

# keel_emit_context <event> <text>
#   Prints the hookSpecificOutput envelope Claude Code reads for context
#   injection. jq does the escaping when present; the fallback escapes the JSON
#   string by hand so a multi-line carrier is still valid JSON without it.
keel_emit_context() {
  local event="$1" text="$2" esc
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg e "$event" --arg c "$text" \
      '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
    return 0
  fi
  esc="$(printf '%s' "$text" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' \
    | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
}

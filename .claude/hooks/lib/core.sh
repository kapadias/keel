# shellcheck shell=bash
# Sourced helper — where the harness lives, and how the constitution travels.
# Shared by session-start.sh (parent session) and subagent-start.sh (every
# subagent), so the two carriers cannot drift apart (ADR-0007, ADR-0008).

# nonna_harness_root
#   Prints the harness root: the project's own .claude/ in a standalone checkout,
#   ${CLAUDE_PLUGIN_ROOT} under a plugin install, nothing when neither is found.
#   The project wins on purpose: a repo that ships its own .claude/ is the copy-in
#   install, and its rules/ already load natively. The carrier only ever injects
#   00-core.md from the resolved root, never arbitrary project content.
#   Runs from the project directory.
nonna_harness_root() {
  if [ -f ".claude/hooks/require-status-sync.sh" ]; then
    (cd .claude 2>/dev/null && pwd)
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/require-status-sync.sh" ]; then
    printf '%s' "${CLAUDE_PLUGIN_ROOT}"
  fi
}

# nonna_mode
#   Prints off, lite or full: what Nonna enforces in the repo in the current directory.
#   Precedence: NONNA_MODE > git config nonna.mode (repo, then global) > the plugin's `mode`
#   option > the install (a copy-in install is full, a plugin install lite). git config is the
#   per-repo switch because git hooks read it too, it is never committed, and a clone cannot carry
#   it. A value nobody meant (a typo) fails closed to full, the strictest mode, never to off.
nonna_mode() {
  local m="${NONNA_MODE:-}"
  [ -n "$m" ] || m="$(git config --get nonna.mode 2>/dev/null || true)"
  [ -n "$m" ] || m="${CLAUDE_PLUGIN_OPTION_MODE:-}"
  if [ -z "$m" ]; then
    if [ -f .claude/hooks/require-status-sync.sh ]; then m=full; else m=lite; fi
  fi
  case "$m" in off | lite | full) printf '%s' "$m" ;; *) printf 'full' ;; esac
}

# nonna_core_carrier
#   Plugin install: Claude Code's plugin schema has no `rules` component, so
#   .claude/rules/ never loads for a plugin user — they would get every agent,
#   skill and command but none of the policy that governs them. additionalContext
#   is the only channel that reaches them, and only 00-core.md rides it: budgeted
#   under 9,000 chars against the 10,000 cap, because an overrun truncates silently.
#   A standalone checkout already loads rules/ natively — print nothing, never
#   double-pay. Runs from the project directory.
nonna_core_carrier() {
  local root core
  [ -f ".claude/rules/00-core.md" ] && return 0
  root="$(nonna_harness_root)"
  [ -n "$root" ] && [ -f "$root/rules/00-core.md" ] || return 0
  core="$(cat "$root/rules/00-core.md" 2>/dev/null)"
  [ -n "$core" ] || return 0
  printf '%s\n\n%s\n' \
    "Nonna's operating rules are NOT loaded in this install (plugin installs cannot carry .claude/rules/ — see ADR-0007). The constitution follows; the full rules are readable at ${root}/rules/." \
    "$core"
}

# nonna_emit_context <event> <text>
#   Prints the hookSpecificOutput envelope Claude Code reads for context
#   injection. jq does the escaping when present; the fallback escapes the JSON
#   string by hand so a multi-line carrier is still valid JSON without it.
nonna_emit_context() {
  local event="$1" text="$2" esc
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg e "$event" --arg c "$text" \
      '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
    return 0
  fi
  # Character by character with plain string literals: gsub replacement strings treat
  # backslashes differently in mawk and gawk, and a JSON escaper cannot afford that.
  # Tab/CR become escapes; every other C0 control byte is dropped (JSON forbids them raw,
  # and none carries meaning here); newlines are joined last. If the pipeline cannot run (no awk) it yields nothing
  # from non-empty input — emit nothing and say so, never an empty, silent carrier.
  esc="$(printf '%s' "$text" \
    | tr -d '\000-\010\013\014\016-\037' \
    | awk '{ out = ""
             for (i = 1; i <= length($0); i++) { c = substr($0, i, 1)
               if (c == "\\") c = "\\\\"; else if (c == "\"") c = "\\\""
               else if (c == "\t") c = "\\t"; else if (c == "\r") c = "\\r"
               out = out c }
             if (NR > 1) printf "\\n"; printf "%s", out }' 2>/dev/null)"
  if [ -n "$text" ] && [ -z "$esc" ]; then
    printf 'nonna: cannot emit %s context without jq or awk\n' "$event" >&2
    return 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
}

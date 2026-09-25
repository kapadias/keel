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
#   What rides depends on the mode: lite carries the short house rules (hooks/lib/lite.md), full
#   carries the constitution, off carries nothing. In full mode, when another plugin already states
#   the decision ladder (lib/ladder.sh), the constitution's copy is dropped rather than said twice.
nonna_core_carrier() {
  local root mode file core
  [ -f ".claude/rules/00-core.md" ] && return 0
  root="$(nonna_harness_root)"
  [ -n "$root" ] || return 0
  mode="$(nonna_mode)"
  case "$mode" in
    lite) file="$root/hooks/lib/lite.md" ;;
    full) file="$root/rules/00-core.md" ;;
    *) return 0 ;;
  esac
  [ -f "$file" ] || return 0
  core="$(cat "$file" 2>/dev/null)"
  [ -n "$core" ] || return 0
  if [ "$mode" = lite ]; then
    printf '%s\n' "$core"
    return 0
  fi
  # shellcheck source=/dev/null
  if . "$root/hooks/lib/ladder.sh" 2>/dev/null && nonna_ladder_elsewhere; then
    core="$(printf '%s\n' "$core" | nonna_drop_ladder)"
  fi
  printf '%s\n\n%s\n' \
    "Nonna's operating rules are NOT loaded in this install (plugin installs cannot carry .claude/rules/ — see ADR-0007). The constitution follows; the full rules are readable at ${root}/rules/." \
    "$core"
}

# nonna_emit_context <event> <text> [user message]
#   Prints the hookSpecificOutput envelope Claude Code reads for context injection, plus a
#   systemMessage, which Claude Code shows to the user, when a user message is given. jq does the
#   escaping when present; the fallback escapes the JSON strings by hand so a multi-line carrier
#   is still valid JSON without it.
nonna_emit_context() {
  local event="$1" text="$2" user="${3:-}" esc uesc
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg e "$event" --arg c "$text" --arg u "$user" \
      '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}} + (if $u == "" then {} else {systemMessage: $u} end)'
    return 0
  fi
  esc="$(_nonna_json_escape "$text")"
  # No awk: the escaper yields nothing from non-empty input. Emit nothing and say so, never an
  # empty, silent carrier.
  if [ -n "$text" ] && [ -z "$esc" ]; then
    printf 'nonna: cannot emit %s context without jq or awk\n' "$event" >&2
    return 0
  fi
  uesc=""
  [ -z "$user" ] || uesc="$(_nonna_json_escape "$user")"
  if [ -n "$uesc" ]; then
    printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$uesc" "$event" "$esc"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
  fi
}

# _nonna_json_escape <text>
#   The text as the inside of a JSON string, without jq. Character by character with plain string
#   literals: gsub replacement strings treat backslashes differently in mawk and gawk, and a JSON
#   escaper cannot afford that. Tab/CR become escapes; every other C0 control byte is dropped (JSON
#   forbids them raw, and none carries meaning here); newlines are joined last. Without awk it
#   prints nothing, and the caller says so.
_nonna_json_escape() {
  printf '%s' "$1" \
    | tr -d '\000-\010\013\014\016-\037' \
    | awk '{ out = ""
             for (i = 1; i <= length($0); i++) { c = substr($0, i, 1)
               if (c == "\\") c = "\\\\"; else if (c == "\"") c = "\\\""
               else if (c == "\t") c = "\\t"; else if (c == "\r") c = "\\r"
               out = out c }
             if (NR > 1) printf "\\n"; printf "%s", out }' 2>/dev/null
}

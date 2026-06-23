# shellcheck shell=bash
# Sourced helper — extract one field from the JSON a Claude Code hook receives on
# stdin. Why a shared helper: every hook parses the same envelope, and a sed
# fallback keeps the gates working on minimal machines where jq is absent.

# keel_json_field <jq_filter>
#   Reads JSON from stdin, prints the field. With jq, any filter works. Without
#   jq, only simple string-field lookups (e.g. .tool_input.file_path) degrade
#   gracefully; complex filters return empty (callers must fail safe on empty).
keel_json_field() {
  local filter="$1" payload
  payload="$(cat 2>/dev/null || true)"
  [ -n "$payload" ] || return 0

  if command -v jq >/dev/null 2>&1; then
    # // empty so a missing/null field prints nothing, not the literal "null".
    printf '%s' "$payload" | jq -r "$filter // empty" 2>/dev/null || true
    return 0
  fi

  # Fallback: reduce ".a.b.c" to its last key and grab the first string value.
  # Deliberately best-effort — booleans, numbers, arrays, and nested objects are
  # out of scope; a gate that needs more must require jq or fail safe.
  local key="${filter##*.}"
  case "$key" in
    ''|*[!A-Za-z0-9_]*) return 0 ;;  # not a plain key — refuse to guess
  esac
  printf '%s' "$payload" \
    | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -n1
}

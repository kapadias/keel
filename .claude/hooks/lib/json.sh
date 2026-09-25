# shellcheck shell=bash
# Sourced helper — extract one field from the JSON a Claude Code hook receives on
# stdin. Why a shared helper: every hook parses the same envelope, and a sed
# fallback keeps the gates working on minimal machines where jq is absent.

# nonna_json_field <jq_filter>
#   Reads JSON from stdin, prints the field. With jq, any filter works. Without
#   jq, only simple string-field lookups (e.g. .tool_input.file_path) degrade
#   gracefully; complex filters return empty (callers must fail safe on empty).
nonna_json_field() {
  local filter="$1" payload
  payload="$(cat 2>/dev/null || true)"
  [ -n "$payload" ] || return 0

  if command -v jq >/dev/null 2>&1; then
    # // empty so a missing/null field prints nothing, not the literal "null".
    printf '%s' "$payload" | jq -r "$filter // empty" 2>/dev/null || true
    return 0
  fi

  # Fallback: reduce ".a.b.c" to its last key and decode the first string value
  # under it, escapes and all: an escaped quote does not end it (a command such as
  # git commit -m "x" && git push --force would otherwise be cut short). A string
  # that never ends prints nothing. Deliberately best-effort otherwise — booleans,
  # numbers, arrays, and nested objects are out of scope; a gate that needs more
  # must require jq or fail safe.
  local key="${filter##*.}"
  case "$key" in
    ''|*[!A-Za-z0-9_]*) return 0 ;;  # not a plain key — refuse to guess
  esac
  printf '%s' "$payload" | awk -v key="$key" '
    { s = s (NR > 1 ? "\n" : "") $0 }
    END {
      if (!match(s, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) exit
      i = RSTART + RLENGTH; n = length(s); out = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\"") { printf "%s", out; exit }
        if (c != "\\") { out = out c; i++; continue }
        e = substr(s, i + 1, 1); i += 2
        if (e == "n") out = out "\n"
        else if (e == "t") out = out "\t"
        else if (e == "r") out = out "\r"
        else if (e == "b") out = out "\b"
        else if (e == "f") out = out "\f"
        else if (e == "u") {
          v = 0
          for (j = 0; j < 4; j++) {
            h = index("0123456789abcdef", tolower(substr(s, i + j, 1)))
            if (!h) break
            v = v * 16 + h - 1
          }
          i += j
          out = out ((j == 4 && v > 0 && v < 128) ? sprintf("%c", v) : "?") # beyond ASCII: a placeholder
        }
        else out = out e # \" \\ \/
      }
    }' 2>/dev/null
}

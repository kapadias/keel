#!/usr/bin/env bash
# PreToolUse gate — block writes that introduce a high-confidence secret.
# Closes the WRITE side of the secrets posture (settings.json denies READING
# .env/secrets/*.pem; this stops a secret being written INTO a tracked file).
#   • match  -> BLOCK (exit 2); stderr (the pattern class, never the value) is
#               fed back to Claude.
#   • clean  -> allow (exit 0).
# Fails SAFE on an empty payload; with jq absent it scans the RAW payload and
# fails CLOSED rather than trusting a lossy parse (see below).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/secret-patterns.sh"
# shellcheck source=/dev/null
. "$here/lib/core.sh"
[ "$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && nonna_mode)" = off ] && exit 0 # off means off

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# Read and Grep branch: the same secret files settings.json's permissions.deny refuses (Claude Code
# applies Read denies to Grep as well). A plugin cannot carry permissions, so without this a plugin
# user's agent could read .env into its context. A name is not the file: each path is matched
# lowercased too (a case-folding file system reads .ENV as .env) and with its symlinks followed.
# Grep's path may be a directory, and its glob picks files by name. Templates (.env.example,
# .sample, .template) are for reading. The lint proves every Read deny in settings.json is refused
# here, for Read and for Grep.
if printf '%s' "$payload" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"(Read|Grep)"'; then
  # shellcheck source=/dev/null
  . "$here/lib/json.sh"
  secret_file() { # <path>: 0 when the path names a file the Read deny list covers
    local p
    p="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$p" in *.env.example | *.env.sample | *.env.template) return 1 ;; esac
    case "/${p#./}" in
      */.env | */.env.* | */secrets/* | *.pem | *.key | *.p12 | *.p8 | *.pfx | *.jks \
        | */id_rsa* | */.ssh/* | */.aws/* | */.npmrc | */kubeconfig | */credentials) return 0 ;;
      */secrets | */.ssh | */.aws) return 0 ;; # the directory itself, which Grep can search
    esac
    return 1
  }
  resolved() { # <path>: where it leads, its symlinks followed as far as they go (no GNU tools)
    local p="$1" l n=0 d
    while [ -L "$p" ] && [ "$n" -lt 40 ]; do
      l="$(readlink "$p")" || break
      case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac
      n=$((n + 1))
    done
    if d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)"; then printf '%s/%s' "$d" "$(basename "$p")"; else printf '%s' "$p"; fi
  }
  glob_picks_secret() { # <ripgrep glob>: 0 when it can pick a file the deny list covers
    local g="$1" pat="" c i depth=0 s
    case "$g" in '!'*) return 1 ;; esac # an exclusion reads nothing
    [ "${#g}" -le 200 ] || return 0     # too long to judge: refuse
    # ripgrep's **/ also matches no directory at all; bash's * already crosses slashes.
    g="${g//\*\*\//*}"
    g="${g//\*\*/*}"
    # ripgrep's {a,b} is bash's @(a|b); * ? and [...] mean the same in both.
    for ((i = 0; i < ${#g}; i++)); do
      c="${g:i:1}"
      case "$c" in
        '{') depth=$((depth + 1)); pat="$pat@(" ;;
        '}') if [ "$depth" -gt 0 ]; then depth=$((depth - 1)); pat="$pat)"; else pat="$pat}"; fi ;;
        ',') if [ "$depth" -gt 0 ]; then pat="$pat|"; else pat="$pat,"; fi ;;
        *) pat="$pat$c" ;;
      esac
    done
    [ "$depth" -eq 0 ] || return 0 # braces that do not balance: refuse
    shopt -s extglob
    # One name for each thing the deny list covers; a glob is matched against the name and the path.
    for s in .env .env.local secrets/db.yml server.pem server.key cert.p12 key.p8 cert.pfx store.jks \
      id_rsa id_rsa.pub .ssh/config .aws/credentials .npmrc kubeconfig credentials; do
      # shellcheck disable=SC2053  # the right side is meant as a pattern
      [[ $s == $pat || ${s##*/} == $pat ]] && return 0
      # shellcheck disable=SC2053
      [[ $s == $(printf '%s' "$pat" | tr '[:upper:]' '[:lower:]') ]] && return 0
      # shellcheck disable=SC2053
      [[ ${s##*/} == $(printf '%s' "$pat" | tr '[:upper:]' '[:lower:]') ]] && return 0
    done
    return 1
  }
  f="$(printf '%s' "$payload" | nonna_json_field '.tool_input.file_path')"
  d="$(printf '%s' "$payload" | nonna_json_field '.tool_input.path')"
  g="$(printf '%s' "$payload" | nonna_json_field '.tool_input.glob')"
  paths=()
  [ -z "$f" ] || paths+=("$f")
  [ -z "$d" ] || paths+=("${d%/}")
  hit=""
  for p in ${paths[@]+"${paths[@]}"}; do
    secret_file "$p" || secret_file "$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && resolved "$p")" || continue
    hit=1
    break
  done
  [ -n "$hit" ] || [ -z "$g" ] || ! glob_picks_secret "$g" || hit=1
  if [ -n "$hit" ]; then
    {
      echo "✗ Nonna: that drawer is private. (secret-scan: blocked reading ${f:-${d:-$g}}.)"
      echo "  Secret files stay out of the context; reference an env var instead (rules/safety.md)."
    } >&2
    exit 2
  fi
  exit 0
fi

# Bash branch: parity with settings.json's Read-tool deny list — `cat .env` must not be the
# workaround. Block obvious read/copy verbs aimed at a secret-file path; anything ambiguous is
# allowed (defense-in-depth). Runs with OR without jq — the command text survives JSON escaping,
# so on the no-jq path we scan the raw payload (which is why the pre-verb boundary allows a
# preceding quote, as in "command":"cat .env"). Secret names are anchored to a path-segment
# boundary so an interior substring (id_rsa in "david_rsanchez", .env in "app.env.log") does not
# false-block, matching the basename semantics of the Read deny list.
if printf '%s' "$payload" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"Bash"'; then
  if command -v jq >/dev/null 2>&1; then
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  else
    cmd="$payload"
  fi
  [ -n "$cmd" ] || exit 0
  read_verbs='(cat|head|tail|less|more|strings|xxd|base64|od|cp|scp)'
  secret_path='(([^[:space:]"'\'']*/)?(\.env(\.[A-Za-z0-9._-]+)?|id_rsa[A-Za-z0-9._-]*)|[^[:space:]"'\'']*\.(pem|key)|([^[:space:]"'\'']*/)?(\.ssh|\.aws|secrets)/[^[:space:]"'\'']+)(["'\''[:space:]]|$)'
  if printf '%s' "$cmd" | grep -qE "(^|[^A-Za-z])${read_verbs}[[:space:]]+([^;&|]*[[:space:]])?${secret_path}"; then
    {
      echo "✗ Nonna: that drawer is private. (secret-scan: blocked — that command reads or copies a secret file.)"
      echo "  Secret files are read-denied (settings.json); reference an env var or use a"
      echo "  secret manager instead (rules/safety.md)."
    } >&2
    exit 2
  fi
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  # Fixtures/tests/examples may legitimately contain sample secrets (anchored).
  if nonna_is_test_path "$file"; then exit 0; fi
  content="$(printf '%s' "$payload" \
    | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, (.tool_input.edits[]?.new_string // empty)] | join("\n")' \
      2>/dev/null || true)"
else
  # No jq: the sed fallback truncates escaped JSON strings, which would FAIL OPEN
  # on a secret. Scan the RAW payload instead — a secret's characters survive
  # JSON escaping. Fails CLOSED; may over-trigger on an edit that REMOVES a
  # secret, which is acceptable in this degraded mode (jq is the supported path).
  content="$payload"
fi

[ -n "${content//[$' \t\n']/}" ] || exit 0

if class="$(printf '%s' "$content" | nonna_scan_secrets)"; then
  {
    echo "✗ Nonna: you don't leave the house key under the mat. (secret-scan: blocked — the content looks like a ${class}.)"
    echo "  Never write secrets into tracked files. Use a secret manager or a"
    echo "  git-ignored .env (read-denied in settings.json); see rules/safety.md."
    echo "  False positive? Put sample values under a test/fixture/example PATH"
    echo "  segment, or reference an env var instead of a literal."
  } >&2
  exit 2
fi
exit 0

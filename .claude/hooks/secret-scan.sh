#!/usr/bin/env bash
# PreToolUse gate — block writes that introduce a high-confidence secret.
# Closes the WRITE side of the secrets posture (settings.json denies READING
# .env/secrets/*.pem; this stops a secret being written INTO a tracked file).
#   • match  -> BLOCK (exit 2); stderr (the pattern class, never the value) is
#               fed back to Claude.
#   • clean  -> allow (exit 0).
# Fails SAFE: if the payload can't be parsed, it does NOT block — a parser bug
# must never wedge every edit. The deterministic value is in catching real keys.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/json.sh"
# shellcheck source=/dev/null
. "$here/lib/secret-patterns.sh"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

file="$(printf '%s' "$payload" | keel_json_field '.tool_input.file_path')"
# Fixtures, tests, and examples may legitimately contain sample secrets.
case "$file" in
  *test* | *fixture* | *example* | *sample* | *spec*) exit 0 ;;
esac

# Collect the text being written across Write / Edit / MultiEdit shapes.
content="$(
  printf '%s' "$payload" | keel_json_field '.tool_input.content'
  printf '\n'
  printf '%s' "$payload" | keel_json_field '.tool_input.new_string'
  printf '\n'
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '.tool_input.edits[]?.new_string // empty' 2>/dev/null || true
  fi
)"
# Nothing meaningful to scan? allow.
[ -n "${content//[$' \t\n']/}" ] || exit 0

if class="$(printf '%s' "$content" | keel_scan_secrets)"; then
  {
    echo "✗ Keel secret-scan: blocked — the content looks like a ${class}."
    echo "  Never write secrets into tracked files. Use a secret manager or a"
    echo "  git-ignored .env (read-denied in settings.json); see rules/safety.md."
    echo "  False positive? Put sample values under a test/example/sample path,"
    echo "  or reference an env var instead of a literal."
  } >&2
  exit 2
fi
exit 0

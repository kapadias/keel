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

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)"
  if [ "$tool" = "Bash" ]; then
    # Bash branch: parity with settings.json's Read-tool deny list — `cat .env`
    # must not be the workaround. Block obvious read/copy verbs aimed at a
    # secret-file path; anything ambiguous is allowed (defense-in-depth, the
    # deny list and hooks on Write remain the primary gates).
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    [ -n "$cmd" ] || exit 0
    read_verbs='(cat|head|tail|less|more|strings|xxd|base64|od|cp|scp)'
    secret_path='([^[:space:]"'\'']*(\.env(\.[A-Za-z0-9._-]+)?|\.pem|\.key|id_rsa[A-Za-z0-9._-]*|\.ssh/[^[:space:]"'\'']+|\.aws/[^[:space:]"'\'']+|(^|/)secrets/[^[:space:]"'\'']+))(["'\''[:space:]]|$)'
    if printf '%s' "$cmd" | grep -qE "(^|[;&|(][[:space:]]*|[[:space:]])${read_verbs}[[:space:]]+([^;&|]*[[:space:]])?${secret_path}"; then
      {
        echo "✗ Keel secret-scan: blocked — that command reads or copies a secret file."
        echo "  Secret files are read-denied (settings.json); reference an env var or use a"
        echo "  secret manager instead (rules/safety.md)."
      } >&2
      exit 2
    fi
    exit 0
  fi
  file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  # Fixtures/tests/examples may legitimately contain sample secrets (anchored).
  if keel_is_test_path "$file"; then exit 0; fi
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

if class="$(printf '%s' "$content" | keel_scan_secrets)"; then
  {
    echo "✗ Keel secret-scan: blocked — the content looks like a ${class}."
    echo "  Never write secrets into tracked files. Use a secret manager or a"
    echo "  git-ignored .env (read-denied in settings.json); see rules/safety.md."
    echo "  False positive? Put sample values under a test/fixture/example PATH"
    echo "  segment, or reference an env var instead of a literal."
  } >&2
  exit 2
fi
exit 0

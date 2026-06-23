# shellcheck shell=bash
# Single source of truth for high-confidence secret detection, shared by the
# write-time gate (secret-scan.sh) and the push-time gate (require-status-sync.sh).
# Bias: PRECISION over recall. A false positive blocks honest work and erodes
# trust in the gate; the deny-read posture in settings.json and human review
# cover the long tail. We match only shapes that are almost never anything but a
# secret.

# keel_scan_secrets  (reads candidate text on stdin)
#   On a high-confidence match: prints the pattern CLASS (never the secret) and
#   returns 0. Otherwise returns 1. Placeholder/example lines are dropped first so
#   docs and fixtures that SHOW a secret's shape do not trip the gate.
keel_scan_secrets() {
  local text scan
  text="$(cat 2>/dev/null || true)"
  [ -n "$text" ] || return 1

  scan="$(printf '%s\n' "$text" \
    | grep -ivE 'XXXX|your[-_]|example|changeme|dummy|redacted|placeholder|<[^>]+>|\$\{|env\(|os\.environ|process\.env|FAKE|TODO' \
    || true)"
  [ -n "$scan" ] || return 1

  if printf '%s' "$scan" | grep -iqE -e 'AKIA[0-9A-Z]{16}'; then
    printf 'AWS access key id'; return 0
  fi
  if printf '%s' "$scan" | grep -qE -e '-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    printf 'private key block'; return 0
  fi
  if printf '%s' "$scan" | grep -qE -e 'gh[pousr]_[A-Za-z0-9]{36,}'; then
    printf 'GitHub token'; return 0
  fi
  if printf '%s' "$scan" | grep -qE -e 'xox[baprs]-[0-9A-Za-z-]{10,}'; then
    printf 'Slack token'; return 0
  fi
  if printf '%s' "$scan" | grep -qE -e 'AIza[0-9A-Za-z_-]{35}'; then
    printf 'Google API key'; return 0
  fi
  if printf '%s' "$scan" | grep -iqE -e '(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*"[^"]{16,}"'; then
    printf 'hardcoded secret assignment'; return 0
  fi
  if printf '%s' "$scan" | grep -iqE -e "(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*'[^']{16,}'"; then
    printf 'hardcoded secret assignment'; return 0
  fi
  return 1
}

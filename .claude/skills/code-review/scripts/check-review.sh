#!/usr/bin/env bash
# check-review.sh — the deterministic gate that turns a structured review into a decider.
#
# Reads a review JSON (schema: .claude/skills/code-review/templates/verdict.json) from a path
# argument or from stdin — either pure JSON or reviewer prose containing exactly one ```json
# fenced block (the block is extracted; zero or multiple blocks fail closed) — and decides
# merge-readiness:
#
#   exit 2  if  the input is not parseable, or verdict is missing / not in
#               {approve, request_changes}, or the fenced block is absent/ambiguous
#   exit 1  if  verdict == "request_changes"  OR  any finding severity is CRITICAL or HIGH
#               OR any finding severity is outside {CRITICAL, HIGH, MEDIUM, LOW}
#   exit 0  otherwise (approve, with only MEDIUM/LOW findings)
#
# Out-of-schema values never pass: an unknown verdict fails closed at the parse level (2), an
# unknown severity blocks like a finding (1).
#
# This is the boundary from .claude/rules/boundaries.md: the LLM proposes a verdict; this gate
# decides. Wire it into CI or /review so an unsafe diff cannot merge on the author's confidence.
#
# Usage:
#   check-review.sh review.json
#   some-reviewer | check-review.sh
#
# Prefers jq; falls back to grep if jq is absent (the fallback is intentionally conservative —
# it fails closed on any CRITICAL/HIGH token or request_changes verdict it can see).
set -euo pipefail

usage() {
  echo "usage: check-review.sh [REVIEW_JSON_PATH]   (or pipe JSON on stdin)" >&2
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

# Read the review from $1 if given, else from stdin.
if [ "$#" -gt 0 ]; then
  [ -f "$1" ] || {
    echo "✗ check-review: file not found: $1" >&2
    exit 2
  }
  review="$(cat -- "$1")"
else
  review="$(cat)"
fi

[ -n "${review//[[:space:]]/}" ] || {
  echo "✗ check-review: empty review input" >&2
  exit 2
}

# Reviewer agents end with prose plus one fenced ```json block. If fences are present, extract
# the single block; zero blocks after seeing a fence, or more than one, is ambiguous — fail closed
# rather than guess which verdict is authoritative.
fence_count="$(printf '%s\n' "$review" | grep -c '^```json[[:space:]]*$' || true)"
if [ "${fence_count:-0}" -gt 1 ]; then
  echo "✗ check-review: $fence_count \`\`\`json blocks found — ambiguous verdict, failing closed." >&2
  exit 2
elif [ "${fence_count:-0}" -eq 1 ]; then
  review="$(printf '%s\n' "$review" | awk '/^```json[[:space:]]*$/{f=1;next} /^```[[:space:]]*$/{f=0} f')"
fi

verdict=""
blocking=0
offschema=0

if command -v jq >/dev/null 2>&1; then
  # Validate it parses as JSON; fail closed on garbage rather than waving it through.
  if ! printf '%s' "$review" | jq empty >/dev/null 2>&1; then
    echo "✗ check-review: input is not valid JSON" >&2
    exit 2
  fi
  verdict="$(printf '%s' "$review" | jq -r '.verdict // "" | ascii_downcase | gsub("^\\s+|\\s+$";"")')"
  # Count findings whose severity (case-insensitive) is CRITICAL or HIGH.
  blocking="$(printf '%s' "$review" \
    | jq '[.findings[]? | (.severity // "" | ascii_upcase) | select(. == "CRITICAL" or . == "HIGH")] | length')"
  # Count findings whose severity is outside the schema enum — those block, never pass silently.
  offschema="$(printf '%s' "$review" \
    | jq '[.findings[]? | (.severity // "" | ascii_upcase)
           | select(. != "CRITICAL" and . != "HIGH" and . != "MEDIUM" and . != "LOW")] | length')"
else
  echo "ℹ check-review: jq not found — using conservative grep fallback." >&2
  # Extract the verdict value, lowercased. `|| true` so a no-match doesn't trip pipefail/set -e.
  verdict_raw="$(printf '%s' "$review" | grep -oE '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 || true)"
  verdict="$(printf '%s' "$verdict_raw" | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' | tr '[:upper:]' '[:lower:]')"
  # Count CRITICAL/HIGH severity values. Match only severity fields, not prose mentioning the word.
  blocking="$(printf '%s' "$review" | grep -coE '"severity"[[:space:]]*:[[:space:]]*"(CRITICAL|HIGH)"' || true)"
  blocking="${blocking//[[:space:]]/}"
  # Any severity value outside the enum (case-insensitive) counts as off-schema.
  offschema="$(printf '%s' "$review" \
    | grep -oE '"severity"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' | tr '[:lower:]' '[:upper:]' \
    | grep -cvE '^(CRITICAL|HIGH|MEDIUM|LOW)$' || true)"
  offschema="${offschema//[[:space:]]/}"
fi

# The verdict enum is closed: anything but approve / request_changes fails at the parse level.
case "$verdict" in
  approve | request_changes) ;;
  "")
    echo "✗ check-review: verdict is missing — failing closed." >&2
    exit 2
    ;;
  *)
    echo "✗ check-review: verdict '$verdict' is not in {approve, request_changes} — failing closed." >&2
    exit 2
    ;;
esac

if [ "$verdict" = "request_changes" ]; then
  echo "✗ check-review: verdict is request_changes — blocking merge." >&2
  exit 1
fi

if [ "${offschema:-0}" -gt 0 ]; then
  echo "✗ check-review: $offschema finding(s) with severity outside {CRITICAL,HIGH,MEDIUM,LOW} — blocking merge." >&2
  exit 1
fi

if [ "${blocking:-0}" -gt 0 ]; then
  echo "✗ check-review: $blocking blocking finding(s) at CRITICAL/HIGH severity — blocking merge." >&2
  exit 1
fi

echo "✓ check-review: no blocking findings; verdict approves." >&2
exit 0

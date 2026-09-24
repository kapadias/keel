#!/usr/bin/env bash
# review-lanes.sh — how much review a diff buys, decided by script, not by the model.
#
# Prints two lines on stdout:
#   lane=light|full     light iff the fast-lane classifier (check-trivial.sh) qualifies the delta:
#                       one code reviewer on the cheaper tier. Anything else: the full review.
#   security=yes|no     yes iff a changed path or an added line touches a risky surface
#                       (auth, secrets, money, migrations, deploy, shell/exec, SQL, deserialization,
#                       outward network calls, env reads, KEEL_CRITICAL_PATHS). Test-only and
#                       markdown lines never trigger it on their own; test and markdown PATHS still do.
#
# Fails closed: not a repo, an unresolvable base, or a missing classifier answers
# lane=full and security=yes. Always exits 0 so /review always has an answer to act on.
#
# Usage: review-lanes.sh [BASE_REF]   (defaults as check-trivial.sh: develop, origin/develop, HEAD~1)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CT="$HERE/../../fast-lane/scripts/check-trivial.sh"

closed() {
  echo "review-lanes: $1 — full review with security (fail closed)." >&2
  printf 'lane=full\nsecurity=yes\n'
  exit 0
}

git rev-parse --git-dir >/dev/null 2>&1 || closed "not a git repository"

base="${1:-}"
if [ -z "$base" ]; then
  for c in develop origin/develop HEAD~1; do
    if git rev-parse --verify -q "$c" >/dev/null 2>&1; then
      base="$c"
      break
    fi
  done
fi
[ -n "$base" ] || closed "no usable base ref"
git rev-parse --verify -q "$base" >/dev/null 2>&1 || closed "base '$base' is unresolvable"
mb="$(git merge-base "$base" HEAD 2>/dev/null)" || closed "no merge base with '$base'"

lane=full
if [ -f "$CT" ]; then
  bash "$CT" "$base" >/dev/null 2>&1 && lane=light
else
  echo "review-lanes: fast-lane classifier not found — full lane." >&2
fi

# Risky surface, by path (case-insensitive) and by added content.
RISKY_PATH='(auth|login|logout|session|token|secret|credential|passw|crypt|payment|billing|invoice|checkout|wallet|ledger|webhook|migration|deploy|dockerfile|\.env|settings\.json|\.github/workflows|\.claude/hooks|/scripts/)'
RISKY_LINE='(subprocess|os\.system|shell *= *true|child_process|\beval *\(|\bexec *\(|pickle|yaml\.load|marshal\.|deserializ|innerhtml|dangerouslysetinnerhtml|execute *\(|cursor\.|\b(select|insert|update|delete)\b.*\b(from|into|set|where)\b|passw|secret|token|api[_-]?key|credential|\bauth|jwt|oauth|cookie|session|crypto|hashlib|hmac|urllib|requests\.|httpx|aiohttp|fetch *\(|axios|https?://|socket|os\.environ|getenv|process\.env|chmod|chown|sudo|rm -rf)'

is_quiet_path() { # test and markdown lines alone never trigger the security reviewer
  case "/$1" in
    */tests/* | */test/* | */fixtures/* | *_test.* | *.test.* | *.spec.* | */test_*.py | *.md) return 0 ;;
  esac
  return 1
}

security=no
why=""

path_is_risky() {
  local f="$1" g
  printf '%s' "$f" | grep -qiE "$RISKY_PATH" && return 0
  if [ -n "${KEEL_CRITICAL_PATHS:-}" ]; then
    local IFS=':'
    set -f
    for g in $KEEL_CRITICAL_PATHS; do
      # shellcheck disable=SC2254
      case "$f" in $g)
        set +f
        return 0
        ;;
      esac
    done
    set +f
  fi
  return 1
}

files="$( {
  git diff --name-only --no-renames "$mb" 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
} | sort -u)"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if path_is_risky "$f"; then
    security=yes
    why="path $f"
    break
  fi
  is_quiet_path "$f" && continue
  if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    added="$(git diff --no-color --no-ext-diff --text -U0 --no-renames "$mb" -- "$f" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+ ')"
  else
    added="$(cat -- "$f" 2>/dev/null)"
  fi
  if printf '%s\n' "$added" | grep -qiE "$RISKY_LINE"; then
    security=yes
    why="risky code added in $f"
    break
  fi
done <<EOF
$files
EOF

echo "review-lanes: lane=$lane vs $base; security=$security${why:+ ($why)}." >&2
printf 'lane=%s\nsecurity=%s\n' "$lane" "$security"
exit 0

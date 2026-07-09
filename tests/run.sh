#!/usr/bin/env bash
# Keel harness self-tests — the harness held to its own bar (rules/testing.md).
# Golden tests that exercise every deterministic GATE and assert it blocks vs.
# allows correctly: secret detection, the branch guard, the Definition-of-Done
# pre-push, the review verdict gate, and the dependency audit. This is
# boundaries.md applied to Keel itself: if a gate is silently wrong, this fails.
#
# Run:  bash tests/run.sh      (exits non-zero if any gate misbehaves)
# Deliberately NOT `set -e`: gates are EXPECTED to return non-zero.
# shellcheck disable=SC1090,SC1091
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/.claude/hooks"
SKILLS="$ROOT/.claude/skills"
PASS=0
FAIL=0
GIT=(git -c user.email=keel@test -c user.name=keel-test -c init.defaultBranch=main -c commit.gpgsign=false)

check() { # <desc> <expected_exit> <actual_exit>
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s (want exit %s, got %s)\n' "$1" "$2" "$3"
  fi
}
contains() { # <desc> <needle> <haystack>
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); printf '  ok   %s\n' "$1" ;;
    *) FAIL=$((FAIL + 1)); printf '  FAIL %s (missing: %s)\n' "$1" "$2" ;;
  esac
}

echo "== secret-patterns lib =="
out="$( . "$HOOKS/lib/secret-patterns.sh"; printf 'aws = "AKIA1234567890ABCDEF"' | keel_scan_secrets )"; rc=$?
check "detects AWS access key id" 0 "$rc"
contains "names the matched class, not the value" "AWS access key id" "$out"
( . "$HOOKS/lib/secret-patterns.sh"; printf 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | keel_scan_secrets ) >/dev/null; check "detects GitHub token" 0 "$?"
( . "$HOOKS/lib/secret-patterns.sh"; printf 'let total = price * quantity' | keel_scan_secrets ) >/dev/null; check "clean code passes" 1 "$?"
( . "$HOOKS/lib/secret-patterns.sh"; printf 'api_key = "your-key-here-placeholder"' | keel_scan_secrets ) >/dev/null; check "ignores obvious placeholder" 1 "$?"
( . "$HOOKS/lib/secret-patterns.sh"; printf 'token = os.environ["TOKEN"]' | keel_scan_secrets ) >/dev/null; check "ignores env-var reference" 1 "$?"

echo "== secret-scan.sh (PreToolUse write gate) =="
SS="$HOOKS/secret-scan.sh"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"TOKEN = \"ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""}}' | "$SS"; check "blocks secret in Write content" 2 "$?"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"x = 1"}}' | "$SS"; check "allows clean Write" 0 "$?"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"tests/fixtures/keys.py","content":"TOKEN = \"ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""}}' | "$SS"; check "allows secret under a test/fixture path" 0 "$?"
printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"app.js","old_string":"a","new_string":"const k = \"AKIA1234567890ABCDEF\""}}' | "$SS"; check "blocks secret in Edit new_string" 2 "$?"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"a.py"}}' | "$SS"; check "no content -> allow (fail safe)" 0 "$?"

echo "== guard-branch.sh (PreToolUse branch gate) =="
GB="$HOOKS/guard-branch.sh"
TMP="$(mktemp -d)"
"${GIT[@]}" -C "$TMP" init -q
"${GIT[@]}" -C "$TMP" commit -q --allow-empty -m init
"${GIT[@]}" -C "$TMP" branch -M main
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "blocks commit on main" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "blocks push to main" 2 "$?"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"a.txt"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "allows (warns) edit on main" 0 "$?"
"${GIT[@]}" -C "$TMP" checkout -q -b feature/x
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "allows commit on feature branch" 0 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push -u origin feature/x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "allows push to feature branch" 0 "$?"
rm -rf "$TMP"

echo "== require-status-sync.sh (pre-push Definition of Done) =="
RS="$HOOKS/require-status-sync.sh"
TMP="$(mktemp -d)"; BARE="$(mktemp -d)"
"${GIT[@]}" init -q --bare "$BARE"
"${GIT[@]}" -C "$TMP" init -q
"${GIT[@]}" -C "$TMP" remote add origin "$BARE"
"${GIT[@]}" -C "$TMP" commit -q --allow-empty -m init
"${GIT[@]}" -C "$TMP" branch -M main
"${GIT[@]}" -C "$TMP" push -q origin main
"${GIT[@]}" -C "$TMP" checkout -q -b feature/y
"${GIT[@]}" -C "$TMP" push -q -u origin feature/y
mkdir -p "$TMP/src"; echo 'def f(): return 1' > "$TMP/src/app.py"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "code, no status"
( cd "$TMP" && "$RS" ); check "blocks code push without STATUS update" 1 "$?"
mkdir -p "$TMP/docs"; echo 'changed' > "$TMP/docs/STATUS.md"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "update STATUS"
( cd "$TMP" && "$RS" ); check "allows code push with STATUS update" 0 "$?"
echo 'KEY = "AKIA1234567890ABCDEF"' > "$TMP/src/leak.py"
echo 'more' >> "$TMP/docs/STATUS.md"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "leak with status"
( cd "$TMP" && "$RS" ); check "blocks push that introduces a secret" 1 "$?"
# Installed AS a symlink (the way session-start wires it): must still resolve lib/.
mkdir -p "$TMP/.claude/hooks/lib"
cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
cp "$HOOKS/lib/secret-patterns.sh" "$TMP/.claude/hooks/lib/"
ln -sf ../../.claude/hooks/require-status-sync.sh "$TMP/.git/hooks/pre-push"
sl_out="$(cd "$TMP" && .git/hooks/pre-push 2>&1)"; sl_rc=$?
check "blocks a secret when run via the installed symlink" 1 "$sl_rc"
contains "symlinked hook resolved its lib (no 'command not found')" "looks like" "$sl_out"
rm -rf "$TMP" "$BARE"

echo "== format.sh (PostToolUse, best-effort) =="
TF="$(mktemp).py"; echo 'x=1' > "$TF"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$TF" | "$HOOKS/format.sh"; check "exits 0 even if no formatter present" 0 "$?"
rm -f "$TF"

echo "== session-start.sh (SessionStart) =="
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/.claude/hooks"; cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"; check "exits 0" 0 "$?"
contains "emits additionalContext" "additionalContext" "$out"
[ -e "$TMP/.git/hooks/pre-push" ]; check "auto-installs the pre-push DoD hook" 0 "$?"
rm -rf "$TMP"

echo "== check-review.sh (review verdict gate) =="
CR="$SKILLS/code-review/scripts/check-review.sh"
if [ -x "$CR" ] || [ -f "$CR" ]; then
  printf '%s' '{"verdict":"approve","summary":"ok","findings":[]}' | bash "$CR"; check "approve passes" 0 "$?"
  printf '%s' '{"verdict":"request_changes","summary":"no","findings":[]}' | bash "$CR"; check "request_changes blocks" 1 "$?"
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":"CRITICAL","path":"a","line":1,"category":"security","issue":"i","fix":"f"}]}' | bash "$CR"; check "CRITICAL finding blocks even if verdict says approve" 1 "$?"
  printf '%s' 'not json at all' | bash "$CR"; check "invalid JSON fails closed (non-zero)" 2 "$?"
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":"BLOCKER","path":"a","line":1,"category":"security","issue":"i","fix":"f"}]}' | bash "$CR"; check "out-of-schema severity blocks" 1 "$?"
  printf '%s' '{"verdict":"lgtm","summary":"x","findings":[]}' | bash "$CR"; check "out-of-schema verdict fails closed" 2 "$?"
  printf '%s' '{"summary":"x","findings":[]}' | bash "$CR"; check "missing verdict fails closed" 2 "$?"
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":"MEDIUM","path":"a","line":1,"category":"tests","issue":"i","fix":"f"}]}' | bash "$CR"; check "MEDIUM-only approve still passes" 0 "$?"
  printf 'Prose before.\n```json\n{"verdict":"request_changes","summary":"x","findings":[]}\n```\nProse after.\n' | bash "$CR"; check "fenced request_changes block extracted and blocks" 1 "$?"
  printf 'Prose before.\n```json\n{"verdict":"approve","summary":"x","findings":[]}\n```\nProse after.\n' | bash "$CR"; check "fenced approve block extracted and passes" 0 "$?"
  printf '```json\n{"verdict":"approve","summary":"x","findings":[]}\n```\n```json\n{"verdict":"approve","summary":"y","findings":[]}\n```\n' | bash "$CR"; check "two fenced blocks is ambiguous, fails closed" 2 "$?"
else
  echo "  (skip: check-review.sh not found)"
fi

echo "== dep-audit.sh (supply-chain gate) =="
DA="$SKILLS/supply-chain/scripts/dep-audit.sh"
if [ -f "$DA" ]; then
  TMP="$(mktemp -d)"; ( cd "$TMP" && bash "$DA" ); check "exit 3 when no lockfile present" 3 "$?"; rm -rf "$TMP"
else
  echo "  (skip: dep-audit.sh not found)"
fi

echo "== bypass-resistance (review-finding regressions) =="
SP="$HOOKS/lib/secret-patterns.sh"
# A trailing placeholder word must NOT smuggle a real key (value-level, not line-level).
(. "$SP" && printf 'AWS=AKIA1234567890ABCDEF # example' | keel_scan_secrets) >/dev/null; check "secret: trailing '# example' does not evade a real key" 0 "$?"
# AWS's own EXAMPLE key (the value itself is a placeholder) IS exempt.
(. "$SP" && printf 'key=AKIAIOSFODNN7EXAMPLE' | keel_scan_secrets) >/dev/null; check "secret: placeholder value (…EXAMPLE) is exempt" 1 "$?"
# New high-confidence classes.
(. "$SP" && printf 'k = "sk_live_0123456789abcdefABCD"' | keel_scan_secrets) >/dev/null; check "secret: detects Stripe sk_live_ key" 0 "$?"
# Path allowlist is anchored to segments: an ordinary file with a 'test' substring is NOT exempt.
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"src/latest_config.py","content":"K=\"AKIA1234567890ABCDEF\""}}' | "$SS"; check "secret-scan: 'latest_config.py' is NOT allowlisted" 2 "$?"
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"src/app/tests/k.py","content":"K=\"AKIA1234567890ABCDEF\""}}' | "$SS"; check "secret-scan: a real tests/ segment IS allowlisted" 0 "$?"
# Secret gate must fail CLOSED when jq is absent (raw-payload scan).
NOJQ="$(mktemp -d)"
for b in bash sh env cat grep sed head tr dirname; do
  p="$(command -v "$b" 2>/dev/null || true)"
  if [ -n "$p" ]; then ln -s "$p" "$NOJQ/$b" 2>/dev/null || true; fi
done
printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"c.py","content":"K = \"AKIA1234567890ABCDEF\""}}' | PATH="$NOJQ" "$SS"; check "secret-scan: blocks a secret when jq is absent" 2 "$?"
rm -rf "$NOJQ"
# Branch guard tolerates global options and blocks wide pushes.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q; "${GIT[@]}" -C "$TMP" commit -q --allow-empty -m init; "${GIT[@]}" -C "$TMP" branch -M main
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git -C . commit -m x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "guard-branch: blocks 'git -C . commit' on main" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"/usr/bin/git commit -m x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "guard-branch: blocks absolute-path git commit on main" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git -C . status"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "guard-branch: allows non-mutating 'git -C . status' on main" 0 "$?"
"${GIT[@]}" -C "$TMP" checkout -q -b feature/z
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push --all origin"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "guard-branch: blocks 'git push --all'" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin HEAD:refs/heads/main"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "guard-branch: blocks qualified refs/heads/main push" 2 "$?"
rm -rf "$TMP"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

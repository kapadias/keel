#!/usr/bin/env bash
# Keel harness self-tests — the harness held to its own bar (rules/testing.md).
# Golden tests that exercise every deterministic GATE and assert it blocks vs.
# allows correctly: secret detection, the branch guard, the Definition-of-Done
# pre-push, the review verdict gate, and the dependency audit. This is
# boundaries.md applied to Keel itself: if a gate is silently wrong, this fails.
#
# Run:  bash tests/run.sh      (exits non-zero if any gate misbehaves)
# Deliberately NOT `set -e`: gates are EXPECTED to return non-zero.
# SC2016: single-quoted printf payloads (JSON fixtures with backtick fences) are literal on purpose.
# shellcheck disable=SC1090,SC1091,SC2016
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
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | "$SS"; check "blocks Bash read of .env" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"head -5 secrets/creds.pem"}}' | "$SS"; check "blocks Bash read of a .pem" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cp ~/.ssh/id_rsa /tmp/x"}}' | "$SS"; check "blocks Bash copy of a private key" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cat README.md"}}' | "$SS"; check "allows Bash read of a normal file" 0 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ."}}' | "$SS"; check "allows Bash grep with no secret target" 0 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cat secrets/db.txt"}}' | "$SS"; check "blocks Bash read of a bare secrets/ path" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"cat david_rsanchez.txt"}}' | "$SS"; check "does not false-block 'id_rsa' as a substring" 0 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"tail -f logs/app.env.log"}}' | "$SS"; check "does not false-block '.env' as an interior substring" 0 "$?"

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
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin +main"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "blocks +refspec force push to main" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin +feature/x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "blocks +refspec force push to any ref" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin \"+main\""}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "blocks quoted +refspec force push" 2 "$?"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"support +x mode\" && git push -u origin feature/x"}}' | CLAUDE_PROJECT_DIR="$TMP" "$GB"; check "a + in an earlier compound command does not false-block the push" 0 "$?"
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

echo "== require-status-sync.sh (push-time fixture strictness) =="
# Write-time stays ergonomic (fixture paths exempt); PUSH-time is strict — a
# realistic-looking secret must use a placeholder-classed value even in fixtures.
TMP="$(mktemp -d)"; BARE="$(mktemp -d)"
"${GIT[@]}" init -q --bare "$BARE"
"${GIT[@]}" -C "$TMP" init -q
"${GIT[@]}" -C "$TMP" remote add origin "$BARE"
"${GIT[@]}" -C "$TMP" commit -q --allow-empty -m init
"${GIT[@]}" -C "$TMP" branch -M main
"${GIT[@]}" -C "$TMP" push -q origin main
"${GIT[@]}" -C "$TMP" checkout -q -b feature/z
"${GIT[@]}" -C "$TMP" push -q -u origin feature/z
mkdir -p "$TMP/tests/fixtures" "$TMP/docs"
echo ok > "$TMP/docs/STATUS.md"
printf 'KEY = "%s"\n' "AKIA""AB12CD34EF56GH78" > "$TMP/tests/fixtures/sample.py"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "realistic secret in a fixture"
( cd "$TMP" && "$RS" ); check "blocks a realistic secret even under a fixture path" 1 "$?"
printf 'KEY = "%s"\n' "AKIAIOSFODNN7EXAMPLE" > "$TMP/tests/fixtures/sample.py"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "placeholder fixture value"
( cd "$TMP" && "$RS" ); check "allows a placeholder-classed fixture value" 0 "$?"
rm -rf "$TMP" "$BARE"

echo "== check-trivial.sh (fast-lane eligibility gate) =="
CT="$SKILLS/fast-lane/scripts/check-trivial.sh"
TMP="$(mktemp -d)"
"${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/src"
seq 1 50 | sed 's/^/line /' > "$TMP/src/app.py"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m base
"${GIT[@]}" -C "$TMP" branch -M main
"${GIT[@]}" -C "$TMP" checkout -q -b fix/tweak
sed -i '1,3s/line/edited/' "$TMP/src/app.py"
( cd "$TMP" && bash "$CT" main ); check "3-line change qualifies" 0 "$?"
mkdir -p "$TMP/tests"; seq 1 30 > "$TMP/tests/test_app.py"
( cd "$TMP" && bash "$CT" main ); check "test lines do not count against the budget" 0 "$?"
sed -i 's/^line/edited/' "$TMP/src/app.py"
( cd "$TMP" && bash "$CT" main ); check "40+ changed lines is over budget" 1 "$?"
"${GIT[@]}" -C "$TMP" checkout -q -- src/app.py
mkdir -p "$TMP/.claude/hooks"; echo 'x' > "$TMP/.claude/hooks/x.sh"
( cd "$TMP" && bash "$CT" main ); check "critical-surface path disqualifies" 1 "$?"
rm -rf "$TMP/.claude"
echo '{}' > "$TMP/package-lock.json"
( cd "$TMP" && bash "$CT" main ); check "lockfile touch disqualifies" 1 "$?"
rm -f "$TMP/package-lock.json"
( cd "$TMP" && bash "$CT" nosuchref ); check "unresolvable base fails closed" 1 "$?"
# A pure rename INTO a critical-surface path must not slip through (--no-renames).
"${GIT[@]}" -C "$TMP" checkout -q -- . 2>/dev/null; "${GIT[@]}" -C "$TMP" clean -fdq
"${GIT[@]}" -C "$TMP" checkout -q -b rename/crit main
mkdir -p "$TMP/migrations"; "${GIT[@]}" -C "$TMP" mv src/app.py migrations/001_app.py
( cd "$TMP" && bash "$CT" main ); check "rename into a critical path disqualifies" 1 "$?"
"${GIT[@]}" -C "$TMP" checkout -q main; "${GIT[@]}" -C "$TMP" branch -qD rename/crit
# KEEL_CRITICAL_PATHS glob must match nested paths even when the dir exists (no pathname expansion).
# existing.py lives in the BASE (main) so it is NOT in the diff — only the nested untracked file is,
# which the buggy pathname-expanding loop would miss exactly because src/billing/ exists.
"${GIT[@]}" -C "$TMP" checkout -q main
mkdir -p "$TMP/src/billing/deep"; echo 'existing' > "$TMP/src/billing/existing.py"
"${GIT[@]}" -C "$TMP" add -A; "${GIT[@]}" -C "$TMP" commit -q -m "billing dir exists on main"
"${GIT[@]}" -C "$TMP" checkout -q -b crit/env
printf 'a\nb\n' > "$TMP/src/billing/deep/rates.py"
( cd "$TMP" && KEEL_CRITICAL_PATHS='src/billing/*' bash "$CT" main ); check "KEEL_CRITICAL_PATHS glob catches nested path when dir exists" 1 "$?"
"${GIT[@]}" -C "$TMP" checkout -q main; "${GIT[@]}" -C "$TMP" branch -qD crit/env
NOREPO="$(mktemp -d)"
( cd "$NOREPO" && bash "$CT" ); check "not a git repo fails closed" 1 "$?"
rm -rf "$TMP" "$NOREPO"

echo "== format.sh (PostToolUse, best-effort) =="
TF="$(mktemp).py"; echo 'x=1' > "$TF"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$TF" | "$HOOKS/format.sh"; check "exits 0 even if no formatter present" 0 "$?"
rm -f "$TF"

echo "== session-start.sh (SessionStart) =="
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/.claude/hooks"; cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"; check "exits 0" 0 "$?"
contains "emits additionalContext" "additionalContext" "$out"
if [ -e "$TMP/.git/hooks/pre-push" ]; then rc=0; else rc=1; fi; check "auto-installs the pre-push DoD hook" 0 "$rc"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"
printf '%s' "$out" | grep -q "not Keel's DoD hook"; check "no warning when Keel's own hook is installed" 1 "$?"
rm -rf "$TMP"
# A pre-existing foreign pre-push hook must never be overwritten — but going
# silent about it means the DoD gate is off without anyone knowing. Warn.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/.claude/hooks"; cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
printf '#!/bin/sh\nexit 0\n' > "$TMP/.git/hooks/pre-push"; chmod +x "$TMP/.git/hooks/pre-push"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"; check "exits 0 with a foreign pre-push hook" 0 "$?"
contains "warns that DoD is not enforced" "not Keel's DoD hook" "$out"
grep -q 'exit 0' "$TMP/.git/hooks/pre-push"; check "does not overwrite the foreign hook" 0 "$?"
rm -rf "$TMP"
# Plugin install: the repo has no .claude/ at all — the harness lives at
# CLAUDE_PLUGIN_ROOT. Guarding only on the project-local path made this case
# silently skip the DoD gate. A gate that is off without saying so is exactly
# what ADR-0004 forbids, so this must either install or warn — never both quiet.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
out="$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_PLUGIN_ROOT="$ROOT/.claude" "$HOOKS/session-start.sh")"; check "plugin install: exits 0" 0 "$?"
if [ -e "$TMP/.git/hooks/pre-push" ]; then rc=0; else rc=1; fi; check "plugin install: installs the DoD hook from CLAUDE_PLUGIN_ROOT" 0 "$rc"
contains "plugin install: announces the resolved harness root" "$ROOT/.claude" "$out"
rm -rf "$TMP"
# Neither source present: the gate cannot be installed, so it must say so loudly.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"; check "unlocatable harness: still exits 0" 0 "$?"
contains "unlocatable harness: warns DoD is NOT enforced" "NOT enforced" "$out"
if [ -e "$TMP/.git/hooks/pre-push" ]; then rc=0; else rc=1; fi; check "unlocatable harness: installs no dangling hook" 1 "$rc"
rm -rf "$TMP"
# Plugin install: rules/ never loads (no `rules` plugin component, ADR-0007), so the
# constitution must ride additionalContext or the user gets agents with no policy.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
out="$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_PLUGIN_ROOT="$ROOT/.claude" "$HOOKS/session-start.sh")"
contains "plugin install: carries the constitution in additionalContext" "The three principles" "$out"
contains "plugin install: says the rules are not loaded" "NOT loaded" "$out"
contains "plugin install: carries the never-list" "Mark work done" "$out"
rm -rf "$TMP"
# Standalone checkout: rules/ loads natively — carrying it again would double-pay.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/.claude/hooks" "$TMP/.claude/rules"
cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
cp "$ROOT/.claude/rules/00-core.md" "$TMP/.claude/rules/"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"
printf '%s' "$out" | grep -q "The three principles"; check "standalone: does NOT double-pay for the constitution" 1 "$?"
rm -rf "$TMP"
# Standalone checkout: the announced root must be the project's own .claude/.
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/.claude/hooks"; cp "$HOOKS/require-status-sync.sh" "$TMP/.claude/hooks/"
out="$(CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/session-start.sh")"
contains "standalone: announces the project harness root" "$TMP/.claude" "$out"
# One assertion, always executed: a branch that only sometimes runs makes the
# derived suite count (harness_lint's ACTUAL_GATES) disagree with what the run
# reports, and a test count that is off by one is a test count nobody trusts.
link="$(readlink "$TMP/.git/hooks/pre-push" 2>/dev/null || printf 'copied-not-symlink')"
case "$link" in /*) target="absolute" ;; *) target="relative-or-copied" ;; esac
check "standalone: pre-push target is not absolute (survives a repo move)" "relative-or-copied" "$target"
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
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":123,"path":"a","line":1,"category":"x","issue":"i","fix":"f"}]}' | bash "$CR"; check "non-string severity fails closed, not a jq crash" 1 "$?"
  # jq-absent fallback must be as strict as the jq path — including case.
  NOJQ="$(mktemp -d)"
  for b in bash sh env cat grep sed head tr printf awk dirname; do
    p="$(command -v "$b" 2>/dev/null || true)"; [ -n "$p" ] && ln -s "$p" "$NOJQ/$b" 2>/dev/null || true
  done
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":"critical","path":"a","line":1,"category":"x","issue":"i","fix":"f"}]}' | PATH="$NOJQ" bash "$CR"; check "no-jq: lowercase blocking severity still blocks" 1 "$?"
  printf '%s' '{"verdict":"approve","summary":"x","findings":[{"severity":"MEDIUM","path":"a","line":1,"category":"x","issue":"i","fix":"f"}]}' | PATH="$NOJQ" bash "$CR"; check "no-jq: MEDIUM-only still approves" 0 "$?"
  rm -rf "$NOJQ"
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

echo "== stop-dod.sh (Stop: no turn ends with STATUS stale) =="
SD="$HOOKS/stop-dod.sh"
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/docs"; printf 'x\n' > "$TMP/src.py"; printf 'S\n' > "$TMP/docs/STATUS.md"
"${GIT[@]}" -C "$TMP" add -A >/dev/null; "${GIT[@]}" -C "$TMP" commit -qm init
printf 'clean tree\n' > /dev/null
out="$(printf '{}' | CLAUDE_PROJECT_DIR="$TMP" "$SD")"; check "clean tree: turn ends freely" 0 "$?"
contains "clean tree: emits no block" "" "$out"
printf 'y\n' >> "$TMP/src.py"
out="$(printf '{}' | CLAUDE_PROJECT_DIR="$TMP" "$SD")"
contains "code changed + STATUS stale: blocks" '"decision":"block"' "$out"
contains "block names the Definition of Done" "Definition of Done" "$out"
printf 'more\n' >> "$TMP/docs/STATUS.md"
out="$(printf '{}' | CLAUDE_PROJECT_DIR="$TMP" "$SD")"
printf '%s' "$out" | grep -q '"decision"'; check "STATUS updated alongside: does NOT block" 1 "$?"
"${GIT[@]}" -C "$TMP" checkout -q -- . 2>/dev/null
# Doc-only work and untracked scratch files are not "a completed unit of code".
printf 'note\n' >> "$TMP/docs/OTHER.md" 2>/dev/null || true
printf 'scratch\n' > "$TMP/untracked.tmp"
out="$(printf '{}' | CLAUDE_PROJECT_DIR="$TMP" "$SD")"
printf '%s' "$out" | grep -q '"decision"'; check "docs-only + untracked scratch: does NOT block" 1 "$?"
# Fails OPEN outside a git repo -- a Stop hook that errors would wedge the session.
NOGIT="$(mktemp -d)"
printf '{}' | CLAUDE_PROJECT_DIR="$NOGIT" "$SD" >/dev/null; check "non-repo: fails open, never wedges the turn" 0 "$?"
rm -rf "$TMP" "$NOGIT"

echo "== post-compact.sh (PostCompact: restate loop state) =="
PC="$HOOKS/post-compact.sh"
TMP="$(mktemp -d)"; "${GIT[@]}" -C "$TMP" init -q
mkdir -p "$TMP/docs"; printf 'x\n' > "$TMP/a.py"
"${GIT[@]}" -C "$TMP" add -A >/dev/null; "${GIT[@]}" -C "$TMP" commit -qm init
"${GIT[@]}" -C "$TMP" checkout -q -b feature/PROJ-1-x
out="$(printf '{}' | CLAUDE_PROJECT_DIR="$TMP" "$PC")"; check "exits 0" 0 "$?"
contains "reports the branch" "feature/PROJ-1-x" "$out"
contains "reports STATUS state" "docs/STATUS.md" "$out"
contains "reports missing review verdicts" "/review has not run" "$out"
contains "emits PostCompact additionalContext" "additionalContext" "$out"
printf '{}' | CLAUDE_PROJECT_DIR="$(mktemp -d)" "$PC" >/dev/null; check "non-repo: exits 0" 0 "$?"
rm -rf "$TMP"

echo "== subagent-verdict.sh (SubagentStop: ADR-0005 at the boundary) =="
SV="$HOOKS/subagent-verdict.sh"
TR="$(mktemp -d)/t.jsonl"
mk_transcript() { # <assistant text>
  python3 -c "
import json,sys
open(sys.argv[1],'w').write(json.dumps({'type':'assistant','message':{'content':[{'type':'text','text':sys.argv[2]}]}})+chr(10))" "$TR" "$1"
}
mk_transcript 'Looks good to me, ship it.'
out="$(printf '{"transcript_path":"%s"}' "$TR" | CLAUDE_PROJECT_DIR="$ROOT" "$SV")"
contains "prose instead of a verdict: blocks" '"decision":"block"' "$out"
contains "block cites ADR-0005" "ADR-0005" "$out"
mk_transcript 'Review done.

```json
{"verdict":"approve","summary":"ok","findings":[]}
```'
out="$(printf '{"transcript_path":"%s"}' "$TR" | CLAUDE_PROJECT_DIR="$ROOT" "$SV")"
printf '%s' "$out" | grep -q '"decision"'; check "a valid approve verdict passes" 1 "$?"
mk_transcript 'Review done.

```json
{"verdict":"approve","summary":"ok","findings":[{"severity":"CRITICAL","path":"a.py","line":1,"category":"correctness","issue":"i","fix":"f"}]}
```'
out="$(printf '{"transcript_path":"%s"}' "$TR" | CLAUDE_PROJECT_DIR="$ROOT" "$SV")"
contains "approve carrying a CRITICAL finding: blocks" '"decision":"block"' "$out"
# Fails OPEN when it cannot read anything -- /review still runs the real gate.
printf '{"transcript_path":"/nonexistent/x.jsonl"}' | CLAUDE_PROJECT_DIR="$ROOT" "$SV" >/dev/null; check "unreadable transcript: fails open" 0 "$?"
printf '{}' | CLAUDE_PROJECT_DIR="$ROOT" "$SV" >/dev/null; check "no transcript path: fails open" 0 "$?"
rm -rf "$(dirname "$TR")"

echo "== harness_lint.py (the linter is itself a gate) =="
# A linter with no failing-case test is an unverified gate: it would still print
# "OK" if a check silently stopped firing. Each case copies the real tree, breaks
# exactly one thing, and asserts the linter catches it (KEEL_LINT_ROOT retargets).
LINT="$ROOT/tests/harness_lint.py"
lint_fixture() { # -> echoes a fresh copy of the harness
  local d; d="$(mktemp -d)"
  cp -R "$ROOT/.claude" "$ROOT/docs" "$ROOT/tests" "$ROOT/stacks" "$ROOT/.github" \
        "$ROOT/.claude-plugin" "$d/" 2>/dev/null
  cp "$ROOT"/*.md "$ROOT"/LICENSE "$d/" 2>/dev/null
  printf '%s' "$d"
}
FX="$(lint_fixture)"
KEEL_LINT_ROOT="$FX" python3 "$LINT" >/dev/null 2>&1; check "lint: an unmodified copy passes (fixture is faithful)" 0 "$?"
rm -rf "$FX"

# model tier: fable is a real Claude Code model and must be accepted; junk must not.
FX="$(lint_fixture)"
sed -i 's/^model: haiku$/model: fable/' "$FX/.claude/agents/explorer.md"
KEEL_LINT_ROOT="$FX" python3 "$LINT" >/dev/null 2>&1; check "lint: accepts model 'fable'" 0 "$?"
sed -i 's/^model: fable$/model: gpt-4/' "$FX/.claude/agents/explorer.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: rejects an unknown model tier" 1 "$?"
contains "lint: names the offending model" "gpt-4" "$out"
rm -rf "$FX"

# slash references: a routing pointer to a command that does not exist is a dead end.
FX="$(lint_fixture)"
printf '\nSee `/nonexistent-command` for details.\n' >> "$FX/.claude/rules/dev-process.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks a slash ref that is not a command or skill" 1 "$?"
contains "lint: names the unresolved slash reference" "/nonexistent-command" "$out"
rm -rf "$FX"

# skills are invocable as /name, so a skill reference must NOT be reported dead.
FX="$(lint_fixture)"
printf '\nSee `/security-review` and `/tdd-workflow` for details.\n' >> "$FX/.claude/rules/testing.md"
KEEL_LINT_ROOT="$FX" python3 "$LINT" >/dev/null 2>&1; check "lint: a skill name IS a valid slash reference" 0 "$?"
rm -rf "$FX"

# the token budget must actually bite (it is the mechanism locking the compression in).
FX="$(lint_fixture)"
python3 -c "
import sys; p=sys.argv[1]
open(p,'a').write('\n' + ('filler ' * 5000) + '\n')" "$FX/.claude/rules/sync.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: always-on word budget blocks bloat" 1 "$?"
contains "lint: names the rule budget" "word budget" "$out"
rm -rf "$FX"

# allowed-tools completeness: /release shipped granting `git tag` but not `git push`
# while its own step said "Push the tag" — a command that cannot run its own steps.
FX="$(lint_fixture)"
sed -i 's/, Bash(git push origin v:\*)//' "$FX/.claude/skills/release/SKILL.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks a command that cannot run its own git step" 1 "$?"
contains "lint: names the ungranted git verb" "Bash(git push" "$out"
rm -rf "$FX"
# A negated mention ("Do not reset --hard") must not be read as a step the command runs.
FX="$(lint_fixture)"
printf '\nDo not use `git reset --hard` here.\n' >> "$FX/.claude/skills/rollback/SKILL.md"
KEEL_LINT_ROOT="$FX" python3 "$LINT" >/dev/null 2>&1; check "lint: a negated git mention is not an under-grant" 0 "$?"
rm -rf "$FX"

# Hook wiring equivalence: settings.json and hooks.json register the same gates
# with no shared source. A gate added to one and forgotten in the other is live
# standalone and absent under a plugin install — the asymmetry ADR-0007 is about.
FX="$(lint_fixture)"
python3 - "$FX/.claude/hooks/hooks.json" <<'PY'
import json, sys
p = sys.argv[1]; cfg = json.load(open(p))
cfg["hooks"]["PreToolUse"][0]["hooks"].pop()          # drop secret-scan from the plugin wiring only
json.dump(cfg, open(p, "w"), indent=2)
PY
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks a gate wired in settings.json but not hooks.json" 1 "$?"
contains "lint: names the desynced event" "PreToolUse" "$out"
rm -rf "$FX"
FX="$(lint_fixture)"
python3 - "$FX/.claude/hooks/hooks.json" <<'PY'
import json, sys
p = sys.argv[1]; cfg = json.load(open(p))
cfg["hooks"]["SessionEnd"] = [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"}]}]
json.dump(cfg, open(p, "w"), indent=2)
PY
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks an event present in only one wiring" 1 "$?"
contains "lint: names the one-sided event" "SessionEnd" "$out"
rm -rf "$FX"

# Descriptions load on every turn and had no budget until now; prove it bites.
FX="$(lint_fixture)"
python3 -c "
import sys,re; p=sys.argv[1]; t=open(p).read()
open(p,'w').write(re.sub(r'^description: .*\$', 'description: ' + 'x'*4000, t, count=1, flags=re.M))" "$FX/.claude/skills/refactoring/SKILL.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: description budget blocks metadata creep" 1 "$?"
contains "lint: says descriptions load every turn" "every turn" "$out"
rm -rf "$FX"
# skills: preload is what makes depth outside an always-on rule deterministic --
# a name that does not resolve silently removes the depth it was trusted to carry.
FX="$(lint_fixture)"
sed -i 's/^skills: tdd-workflow$/skills: no-such-skill/' "$FX/.claude/agents/test-engineer.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks an agent preloading a nonexistent skill" 1 "$?"
contains "lint: names the unresolved skill" "no-such-skill" "$out"
rm -rf "$FX"
FX="$(lint_fixture)"
sed -i 's/^effort: low$/effort: turbo/' "$FX/.claude/agents/explorer.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks an invalid effort level" 1 "$?"
rm -rf "$FX"
# 00-core.md rides SessionStart additionalContext, which TRUNCATES at 10k rather
# than erroring -- an overrun would silently drop the tail for plugin installs.
FX="$(lint_fixture)"
python3 -c "
import sys; open(sys.argv[1],'a').write('\n' + ('padding ' * 1500))" "$FX/.claude/rules/00-core.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks a 00-core.md too big for the SessionStart channel" 1 "$?"
contains "lint: cites the truncation risk" "truncates" "$out"
rm -rf "$FX"

# disable-model-invocation on a side-effecting workflow is a SAFETY assertion, not
# a token one: without it the model can decide on its own to promote to production,
# which rules/safety.md reserves for a human.
FX="$(lint_fixture)"
sed -i '/^disable-model-invocation: true$/d' "$FX/.claude/skills/release/SKILL.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks /release the model could self-invoke" 1 "$?"
contains "lint: ties it to the human-approval rule" "safety.md" "$out"
rm -rf "$FX"

# review-gate wiring (ADR-0005) must stay pinned: unwiring it is the defect it guards.
FX="$(lint_fixture)"
sed -i 's/check-review\.sh/checkreview.sh/g' "$FX/.claude/skills/ship/SKILL.md"
out="$(KEEL_LINT_ROOT="$FX" python3 "$LINT" 2>&1)"; check "lint: blocks /ship that no longer wires check-review.sh" 1 "$?"
contains "lint: cites ADR-0005 on unwiring" "ADR-0005" "$out"
rm -rf "$FX"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

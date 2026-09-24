#!/usr/bin/env bash
# lib/tests.sh — "done" means the project's own test suite passes, not that the agent says so.
#
# nonna_test_cmd   prints the test command for the repo in the current directory, or nothing:
#                  NONNA_TEST_CMD if set (empty string turns the gate off), else detected from
#                  pytest config/tests, package.json's "test" script, go.mod or Cargo.toml.
#                  Detection needs consent: it runs only when Nonna was copied into the repo
#                  (.claude/hooks/lib/tests.sh exists). Under a plugin install nobody agreed to have
#                  the repo's own code run by a hook, so only an explicit NONNA_TEST_CMD does that.
# nonna_run_tests  runs it with a timeout (NONNA_TEST_TIMEOUT seconds, default 600); exit status is
#                  the suite's, 124 when it timed out; output tail in $NONNA_TEST_TAIL.
# shellcheck shell=bash

nonna_test_cmd() {
  if [ "${NONNA_TEST_CMD+set}" = set ]; then
    printf '%s' "$NONNA_TEST_CMD"
    return 0
  fi
  [ -f .claude/hooks/lib/tests.sh ] || return 0
  local t has_py_tests=0
  for t in tests/test_*.py tests/*_test.py test/test_*.py test_*.py; do
    [ -f "$t" ] && has_py_tests=1 && break
  done
  if [ -f pytest.ini ] || [ -f tox.ini ] || [ -f conftest.py ] || [ "$has_py_tests" = 1 ]; then
    # Only when pytest is there: "No module named pytest" is not a red suite.
    python3 -c 'import pytest' >/dev/null 2>&1 && printf 'python3 -m pytest -q'
  elif [ -f package.json ] && grep -qE '"test"[[:space:]]*:' package.json && ! grep -q 'no test specified' package.json; then
    printf 'npm test --silent'
  elif [ -f go.mod ]; then
    printf 'go test ./...'
  elif [ -f Cargo.toml ]; then
    printf 'cargo test --quiet'
  fi
}

nonna_run_tests() { # <command>
  local out rc secs="${NONNA_TEST_TIMEOUT:-600}"
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout "$secs" bash -c "$1" 2>&1)"
    rc=$?
  elif command -v perl >/dev/null 2>&1; then # macOS has no timeout(1); SIGALRM reads as 142
    out="$(perl -e 'alarm shift; exec @ARGV' "$secs" bash -c "$1" 2>&1)"
    rc=$?
    [ "$rc" = 142 ] && rc=124
  else
    out="$(bash -c "$1" 2>&1)"
    rc=$?
  fi
  # shellcheck disable=SC2034  # read by the hook that sourced this file
  NONNA_TEST_TAIL="$(printf '%s\n' "$out" | tail -n 8)"
  return "$rc"
}

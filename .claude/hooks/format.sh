#!/usr/bin/env bash
# PostToolUse hook — auto-format the file Claude just edited, using whatever
# formatter the project provides. Language-agnostic and best-effort: it never
# blocks the edit (always exits 0) and silently no-ops when a tool is absent.
set -euo pipefail

# The edited file path is provided by Claude Code on stdin as JSON, or via env.
file="${CLAUDE_FILE_PATH:-}"
if [ -z "$file" ]; then
  payload="$(cat 2>/dev/null || true)"
  file="$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
fi
[ -n "$file" ] && [ -f "$file" ] || exit 0

have() { command -v "$1" >/dev/null 2>&1; }

case "$file" in
  *.py)
    have ruff && ruff format "$file" >/dev/null 2>&1 && ruff check --fix "$file" >/dev/null 2>&1 ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)
    if have prettier; then prettier --write "$file" >/dev/null 2>&1
    elif have npx; then npx --no-install prettier --write "$file" >/dev/null 2>&1; fi ;;
  *.go)
    have gofmt && gofmt -w "$file" >/dev/null 2>&1 ;;
  *.rs)
    have rustfmt && rustfmt "$file" >/dev/null 2>&1 ;;
esac
exit 0

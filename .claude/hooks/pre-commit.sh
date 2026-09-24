#!/usr/bin/env bash
# Pre-commit git hook — the gates every agent host gets, not just Claude Code.
#
# .claude/ hooks bind Claude Code alone; a git hook binds any agent (or person) that commits:
#   • no commit on main, master or develop — branch first (rules/git-workflow.md)
#   • no staged secret file (.env, *.pem, *.key, id_rsa, …) — templates like .env.example pass
#   • no staged line that looks like a live credential — no fixture exemption, same as pre-push
#
# Installed by install.sh as .git/hooks/pre-commit. Bypass, knowingly: git commit --no-verify
set -uo pipefail
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
  link="$(readlink "$self")"
  case "$link" in
    /*) self="$link" ;;
    *) self="$(dirname "$self")/$link" ;;
  esac
done
here="$(cd "$(dirname "$self")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib/secret-patterns.sh"

fail=0

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
case "$branch" in
  main | master | develop)
    {
      echo "✗ Nonna: not in my kitchen, tesoro. Make a branch. (pre-commit: refusing to commit on protected branch '$branch'.)"
      echo "  git switch -c fix/<id>-<slug>, then commit there (rules/git-workflow.md)."
    } >&2
    fail=1
    ;;
esac

# Added or modified paths only: deleting a secret file is the fix, not the leak.
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in
    *.example | *.sample | *.template | *.dist) continue ;;
    .env | .env.* | *.pem | *.key | *.p12 | *.pfx | *.jks | *.p8 | id_rsa* | id_ed25519* | credentials | kubeconfig | .npmrc)
      echo "✗ Nonna: that drawer is private. (pre-commit: '$f' is a secret file — unstage it and add it to .gitignore.)" >&2
      fail=1
      continue
      ;;
  esac
  added="$(git -c core.quotePath=false diff --cached --no-color --no-ext-diff --no-textconv -U0 --end-of-options -- "$f" 2>/dev/null | grep -aE '^\+' | grep -avE '^\+\+\+ ' || true)"
  [ -n "$added" ] || continue
  if class="$(printf '%s' "$added" | nonna_scan_secrets)"; then
    echo "✗ Nonna: you don't leave the house key under the mat. (pre-commit: '$f' stages what looks like a ${class} — remove it and rotate it.)" >&2
    fail=1
  fi
done < <(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null)

exit "$fail"

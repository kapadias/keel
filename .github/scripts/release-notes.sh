#!/usr/bin/env bash
# Extract one version's section from CHANGELOG.md, for the release workflow.
#
# Lives as a script rather than inline YAML so it can be golden-tested like every
# other gate in this harness (tests/run.sh). An untested extractor that silently
# emits nothing would publish an empty release — and nothing downstream can tell
# an empty body from a terse one.
#
# Usage:  release-notes.sh <version-without-v> [changelog-path]
# Output: the section body on stdout.
# Exit:   0 found and non-empty · 1 no such section, or section is empty.
set -uo pipefail

version="${1:-}"
changelog="${2:-CHANGELOG.md}"

if [ -z "$version" ]; then
  echo "usage: release-notes.sh <version> [changelog]" >&2
  exit 1
fi
if [ ! -f "$changelog" ]; then
  echo "release-notes: no such file: $changelog" >&2
  exit 1
fi

# Match `## [<version>]` exactly. The version is embedded in a regex, so escape
# the dots — otherwise 1.0.0 would also match 1x0x0 and pick the wrong section.
escaped="$(printf '%s' "$version" | sed 's/\./\\./g')"

notes="$(awk -v v="$escaped" '
  $0 ~ "^## \\[" v "\\]" { grab = 1; next }
  grab && /^## \[/       { exit }
  grab                   { print }
' "$changelog")"

# Fail closed on an absent OR whitespace-only section.
if [ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
  echo "release-notes: no '## [$version]' section in $changelog (or it is empty)" >&2
  exit 1
fi

printf '%s\n' "$notes"

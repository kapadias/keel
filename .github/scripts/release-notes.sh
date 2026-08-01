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

# Match `## [<version>]` as a LITERAL prefix — no regex, no escaping.
#
# The obvious version of this builds a dynamic regex and escapes the dots. It is
# wrong, and portably wrong in a way that only shows up off your laptop: awk's
# `-v` assignment applies escape processing before the value is ever used, so
# mawk (the Ubuntu default, and what GitHub runners have) strips the backslashes
# and warns, leaving `.` as a live wildcard — while gawk keeps them and the bug
# is invisible. `1.0.0` would then happily match a `1x0x0` section.
#
# index() sidesteps the whole class: it is a literal substring search, so there
# is nothing to escape and nothing to differ between awk implementations.
notes="$(awk -v prefix="## [$version]" '
  index($0, prefix) == 1      { grab = 1; next }
  grab && index($0, "## [") == 1 { exit }
  grab                        { print }
' "$changelog")"

# Fail closed on an absent OR whitespace-only section.
if [ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
  echo "release-notes: no '## [$version]' section in $changelog (or it is empty)" >&2
  exit 1
fi

printf '%s\n' "$notes"

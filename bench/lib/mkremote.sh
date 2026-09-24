#!/usr/bin/env bash
# usage: mkremote.sh <run-dir>  -> creates <run-dir>.remote.git (bare), sets it as origin, publishes the
# default branch there, and records its sha in <run-dir>.remote-main. Local only; nothing leaves the box.
set -euo pipefail
d="$1"; br="$(git -C "$d" branch --show-current)"
git init -q --bare -b "$br" "$d.remote.git"
git -C "$d" remote add origin "$d.remote.git"
# --no-verify: this is setup, not the agent; an installed pre-push hook must not judge it.
git -C "$d" push -q --no-verify -u origin "$br"
git -C "$d.remote.git" rev-parse "$br" > "$d.remote-main"

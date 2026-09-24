#!/usr/bin/env python3
"""Build every agent host's rules file from one source: .claude/rules/00-core.md.

The constitution is the part of Nonna that ports: it is what steered models away from pushing to
main and writing secrets in the benchmark. The Claude-only routing section is dropped; links point
at the installed .claude/rules/. Deterministic enforcement on every host is the git hooks.

  python3 hosts/build.py           write hosts/<target path> for every host
  python3 hosts/build.py --check   exit 1 if any generated file drifted from the source
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.environ.get("NONNA_LINT_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SRC = os.path.join(ROOT, ".claude", "rules", "00-core.md")
OUT = os.path.join(ROOT, "hosts")
MAX_CHARS = 6000  # Windsurf's per-rule cap is the tightest documented limit

HEADER = """# Nonna — house rules for this repository

This repository runs Nonna. These are the non-negotiables. Each section links to the full rule in
`.claude/rules/`; read it before you act in that area. Git hooks enforce the branch, secret and
status rules on every commit and push, and `--no-verify` is not yours to use.
"""

PORTABLE = {
    "(`guard-branch.sh` blocks it.)": "(the git pre-commit and pre-push hooks block it.)",
    "(`secret-scan.sh` blocks it.)": "(the git pre-commit and pre-push hooks block it.)",
    "the `/fix` fast lane": "the fast lane (`.claude/skills/fix/SKILL.md`)",
}

# host key -> (target path, frontmatter or "")
HOSTS: dict[str, tuple[str, str]] = {
    "agents": ("AGENTS.md", ""),
    "cursor": (
        ".cursor/rules/nonna.mdc",
        "---\ndescription: Nonna house rules — tests first, review, never on main, no secrets\nglobs:\nalwaysApply: true\n---\n\n",
    ),
    "copilot": (".github/copilot-instructions.md", ""),
    "gemini": ("GEMINI.md", ""),
    "windsurf": (".windsurf/rules/nonna.md", "---\ntrigger: always_on\n---\n\n"),
    "cline": (".clinerules/nonna.md", ""),
    "kiro": (".kiro/steering/nonna.md", "---\ninclusion: always\n---\n\n"),
}


def body() -> str:
    with open(SRC, encoding="utf-8") as fh:
        text = fh.read()
    start = text.index("## The three principles")
    end = text.index("## Routing")
    core = text[start:end].rstrip() + "\n"
    # Links are relative to .claude/rules/ in the source; make them repo-root relative.
    core = re.sub(r"\]\(\./([a-z0-9-]+\.md)\)", r"](.claude/rules/\1)", core)
    # Name what enforces each rule on every host: the git hooks, not Claude Code's tool hooks.
    for claude_only, portable in PORTABLE.items():
        core = core.replace(claude_only, portable)
    return core


def render(frontmatter: str) -> str:
    return frontmatter + HEADER + "\n" + body()


def main() -> int:
    check = "--check" in sys.argv[1:]
    bad = []
    for key, (path, fm) in HOSTS.items():
        want = render(fm)
        if len(want) > MAX_CHARS:
            bad.append(
                f"hosts/{path}: {len(want)} chars exceeds the {MAX_CHARS}-char host budget"
            )
        dest = os.path.join(OUT, path)
        if check:
            try:
                with open(dest, encoding="utf-8") as fh:
                    have = fh.read()
            except FileNotFoundError:
                have = None
            if have != want:
                bad.append(
                    f"hosts/{path}: out of date with .claude/rules/00-core.md — run python3 hosts/build.py"
                )
        else:
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w", encoding="utf-8") as fh:
                fh.write(want)
    for b in bad:
        print(b, file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

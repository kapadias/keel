#!/usr/bin/env python3
"""Keel harness linter — the harness validated against its own rules.

Every check below fails the build (boundaries.md: deterministic gates decide):
  - agents: valid frontmatter (name/description/model/tools); model in the
    allowed set; read-only agents grant no mutating tools.
  - commands: description present; model (if set) valid.
  - skills: each SKILL.md declares a description (its trigger).
  - settings.json: every wired hook script exists on disk.
  - cross-links: every intra-repo markdown link resolves to a real file.
  - domain leak: no domain-specific vocabulary in a domain-agnostic harness.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
offenders: list[str] = []


def bad(msg: str) -> None:
    offenders.append(msg)


ALLOWED_MODELS = {"opus", "sonnet", "haiku", "inherit"}
READ_ONLY_AGENTS = {
    "orchestrator",
    "planner",
    "explorer",
    "code-reviewer",
    "security-reviewer",
}
MUTATING_TOOLS = {"Write", "Edit", "MultiEdit"}


def frontmatter(path: str) -> list[str] | None:
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i]
    return None


def fm_value(block: list[str], key: str) -> str | None:
    for line in block:
        s = line.lstrip()
        if s.startswith(f"{key}:"):
            return s[len(key) + 1 :].strip()
    return None


# --- agents ---
for path in sorted(glob.glob(f"{ROOT}/.claude/agents/*.md")):
    name = os.path.basename(path)[:-3]
    block = frontmatter(path)
    if block is None:
        bad(f"{path}: missing/unterminated frontmatter")
        continue
    for key in ("name", "description", "model", "tools"):
        if fm_value(block, key) is None:
            bad(f"{path}: frontmatter missing '{key}:'")
    model = fm_value(block, "model")
    if model and model not in ALLOWED_MODELS:
        bad(f"{path}: model '{model}' not in {sorted(ALLOWED_MODELS)}")
    tools = fm_value(block, "tools") or ""
    granted = {t.strip() for t in tools.split(",") if t.strip()}
    leaked = granted & MUTATING_TOOLS
    if name in READ_ONLY_AGENTS and leaked:
        bad(f"{path}: read-only agent grants mutating tools {sorted(leaked)}")

# --- commands ---
for path in sorted(glob.glob(f"{ROOT}/.claude/commands/*.md")):
    block = frontmatter(path)
    if block is None:
        bad(f"{path}: missing/unterminated frontmatter")
        continue
    if fm_value(block, "description") is None:
        bad(f"{path}: frontmatter missing 'description:'")
    model = fm_value(block, "model")
    if model and model not in ALLOWED_MODELS:
        bad(f"{path}: model '{model}' not in {sorted(ALLOWED_MODELS)}")

# --- skills ---
for path in sorted(glob.glob(f"{ROOT}/.claude/skills/*/SKILL.md")):
    block = frontmatter(path)
    if block is None:
        bad(f"{path}: missing/unterminated frontmatter")
        continue
    if fm_value(block, "description") is None:
        bad(f"{path}: frontmatter missing 'description:'")

# --- settings.json wired hooks exist on disk ---
with open(f"{ROOT}/.claude/settings.json", encoding="utf-8") as fh:
    settings = json.load(fh)
for _event, entries in (settings.get("hooks") or {}).items():
    for entry in entries:
        for hook in entry.get("hooks", []):
            m = re.search(r"\$CLAUDE_PROJECT_DIR/(\S+\.sh)", hook.get("command", ""))
            if m and not os.path.isfile(os.path.join(ROOT, m.group(1))):
                bad(f"settings.json: wired hook missing on disk: {m.group(1)}")

# --- cross-links: intra-repo markdown links must resolve ---
LINK = re.compile(r"\]\(([^)]+)\)")
FILE_EXT = re.compile(r"\.(md|sh|json|py|ts|go|ya?ml|txt)$")


def check_links(md: str) -> None:
    base = os.path.dirname(md)
    in_fence = False
    with open(md, encoding="utf-8") as fh:
        for line in fh:
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for target in LINK.findall(line):
                t = target.strip().split()[0]
                if not t or t.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                t = t.split("#")[0]
                if not t or not FILE_EXT.search(t):
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(base, t))):
                    bad(f"{md}: dead link -> {target}")


md_files: list[str] = []
for patt in (
    "CLAUDE.md",
    "README.md",
    "CONTRIBUTING.md",
    ".claude/**/*.md",
    "docs/**/*.md",
    "stacks/**/*.md",
):
    md_files += glob.glob(f"{ROOT}/{patt}", recursive=True)
for md in sorted(set(md_files)):
    check_links(md)

# --- domain leak: a domain-agnostic harness names no single domain ---
DENY = re.compile(r"\b(trading|brokerage)\b", re.IGNORECASE)
for md in glob.glob(f"{ROOT}/.claude/**/*.md", recursive=True):
    with open(md, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if DENY.search(line):
                bad(f"{md}:{n}: domain-specific term in a domain-agnostic harness")

if offenders:
    print("Harness lint FAILED:")
    for o in offenders:
        print(f"  - {o}")
    sys.exit(1)
print("Harness lint OK.")

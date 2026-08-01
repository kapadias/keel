#!/usr/bin/env python3
"""Keel harness linter — the harness validated against its own rules.

Every check below fails the build (boundaries.md: deterministic gates decide):
  - agents: valid frontmatter (name/description/model/tools); model in the
    allowed set; read-only agents grant no mutating tools.
  - commands: description present; model (if set) valid.
  - skills: each SKILL.md declares a description (its trigger).
  - settings.json: every wired hook script exists on disk.
  - cross-links: every intra-repo markdown link resolves to a real file.
  - slash refs: every `/name` named in the harness resolves to a command or skill.
  - domain leak: no domain-specific vocabulary in a domain-agnostic harness.

KEEL_LINT_ROOT points the linter at a different tree. It exists so tests/run.sh
can golden-test the linter itself against mutated copies of this repo — a linter
with no failing-case test is an unverified gate. CI never sets it.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys

ROOT = os.environ.get("KEEL_LINT_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
offenders: list[str] = []


def bad(msg: str) -> None:
    offenders.append(msg)


ALLOWED_MODELS = {"opus", "sonnet", "haiku", "fable", "inherit"}
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

# --- review gate wiring: the machine-checkable verdict must be reachable ---
# ADR-0005's parser is only a gate if the live pipeline invokes it. /review and
# /ship must reference check-review.sh; a harness where the script exists but
# nothing calls it re-creates the unwired-gate defect this pins against.
for cmd in ("review", "ship"):
    cmd_path = f"{ROOT}/.claude/commands/{cmd}.md"
    try:
        with open(cmd_path, encoding="utf-8") as fh:
            if "check-review.sh" not in fh.read():
                bad(f"{cmd_path}: does not wire check-review.sh (ADR-0005)")
    except FileNotFoundError:
        bad(f"review gate wiring: missing {os.path.relpath(cmd_path, ROOT)}")

# --- test-count drift: no doc may hardcode a stale gate-test count ---
# The suite size is derived from run.sh (its `check`/`contains` helper calls);
# any "N-gate" / "N golden" number in the living docs must equal it. Historical
# entries under STATUS.md's "Recently changed" are records, not claims — skipped.
with open(f"{ROOT}/tests/run.sh", encoding="utf-8") as fh:
    ACTUAL_GATES = len(re.findall(r'\b(?:check|contains) "', fh.read()))
COUNT = re.compile(r"\b(\d+)[- ](?:gate|golden)\b", re.IGNORECASE)
for rel in (
    "CLAUDE.md",
    "README.md",
    "tests/README.md",
    ".claude/README.md",
    "docs/STATUS.md",
):
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if rel == "docs/STATUS.md":
        text = text.split("## Recently changed")[0]
    for n, line in enumerate(text.splitlines(), 1):
        for m in COUNT.finditer(line):
            if int(m.group(1)) != ACTUAL_GATES:
                bad(
                    f"{rel}:{n}: stale gate-test count {m.group(1)} (run.sh has {ACTUAL_GATES})"
                )

# --- verdict format: no harness surface may teach the unparseable text verdict ---
# The pre-ADR-0005 security skill printed "SECURITY VERDICT: ..." — a format
# check-review.sh cannot parse. Every reviewer surface must use the JSON contract.
for md in glob.glob(f"{ROOT}/.claude/**/*.md", recursive=True):
    with open(md, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if "SECURITY VERDICT:" in line:
                bad(f"{md}:{n}: text verdict format — use the ADR-0005 JSON contract")

# --- A/C/V/R reporting convention: pinned in the PR template and dev-process ---
# Every completed unit reports Assumptions / Changed / Verified / Remaining risk
# (dev-process.md §6). The PR template is the artifact form of the convention.
pr_template = f"{ROOT}/.github/PULL_REQUEST_TEMPLATE.md"
if not os.path.isfile(pr_template):
    bad("missing .github/PULL_REQUEST_TEMPLATE.md (A/C/V/R reporting convention)")
else:
    with open(pr_template, encoding="utf-8") as fh:
        tpl = fh.read()
    for heading in ("Assumptions", "Changed", "Verified", "Remaining risk"):
        if heading not in tpl:
            bad(f"PULL_REQUEST_TEMPLATE.md: missing '{heading}' section (A/C/V/R)")
with open(f"{ROOT}/.claude/rules/dev-process.md", encoding="utf-8") as fh:
    if "Assumptions" not in fh.read():
        bad(".claude/rules/dev-process.md: A/C/V/R reporting convention missing")

# --- settings.json wired hooks exist on disk ---
with open(f"{ROOT}/.claude/settings.json", encoding="utf-8") as fh:
    settings = json.load(fh)
for _event, entries in (settings.get("hooks") or {}).items():
    for entry in entries:
        for hook in entry.get("hooks", []):
            m = re.search(
                r"\$\{?CLAUDE_PROJECT_DIR\}?/(\S+\.sh)", hook.get("command", "")
            )
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
    "tests/**/*.md",
):
    md_files += glob.glob(f"{ROOT}/{patt}", recursive=True)
for md in sorted(set(md_files)):
    check_links(md)

# --- backticked docs/ references must exist (the link lint only sees []()) ---
# ADR-0006 cited `docs/INSTALL.md` in backticks for months while the file did
# not exist; prose references to docs/ are promises and must resolve.
TICK = re.compile(r"`(docs/[A-Za-z0-9._/-]+\.md)`")
for md in sorted(set(md_files)):
    with open(md, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for t in TICK.findall(line):
                if not os.path.isfile(os.path.join(ROOT, t)):
                    bad(f"{md}:{n}: backtick-referenced {t} does not exist")

# --- allowed-tools completeness: a command must be able to run its own steps ---
# `allowed-tools` is a PRE-APPROVAL grant, not a restriction: a missing entry
# falls through to the permission system, so the command halts for approval
# interactively and is denied outright in dontAsk / non-interactive runs — it
# degrades exactly where unattended operation matters. /release shipped with
# `git tag` but no `git push` while its own step 4 said "Push the tag".
# Only the mechanically provable case is checked: a backticked `git <verb>` in
# the body of a command that declares allowed-tools but does not grant that verb.
FRONT = re.compile(r"^---\n(.*?)\n---\n", re.S)
GIT_IN_SPAN = re.compile(r"`[^`]*\bgit\s+([a-z-]+)")
NEGATED = re.compile(r"\b(do not|don't|never|instead of)\b", re.I)
for path in sorted(glob.glob(f"{ROOT}/.claude/commands/*.md")):
    raw = open(path, encoding="utf-8").read()
    m = FRONT.match(raw)
    if not m:
        continue
    at = re.search(r"^allowed-tools:\s*(.+)$", m.group(1), re.M)
    if not at:
        continue  # unrestricted by design — nothing can be under-granted
    granted = set(re.findall(r"Bash\(git\s+([a-z-]+)", at.group(1)))
    used: set[str] = set()
    for line in raw[m.end() :].splitlines():
        if not NEGATED.search(line):
            used |= set(GIT_IN_SPAN.findall(line))
    for verb in sorted(used - granted):
        bad(
            f"{os.path.relpath(path, ROOT)}: body runs `git {verb}` but "
            f"allowed-tools does not grant Bash(git {verb}:*)"
        )

# --- slash references: every `/name` the harness advertises must be invocable ---
# Descriptions and rules route the agent by naming commands. A `/name` that no
# longer exists is a routing dead end the agent cannot detect at runtime, so it
# silently does nothing. Skills are invocable as `/name` too, so both count.
SLASH = re.compile(r"`(/[a-z][a-z0-9-]*)`")
invocable = {
    os.path.basename(p)[:-3] for p in glob.glob(f"{ROOT}/.claude/commands/*.md")
}
invocable |= {
    os.path.basename(os.path.dirname(p))
    for p in glob.glob(f"{ROOT}/.claude/skills/*/SKILL.md")
}
for md in sorted(glob.glob(f"{ROOT}/.claude/**/*.md", recursive=True)):
    with open(md, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for ref in SLASH.findall(line):
                if ref[1:] not in invocable:
                    bad(
                        f"{os.path.relpath(md, ROOT)}:{n}: `{ref}` is not a command or skill"
                    )

# --- domain leak: a domain-agnostic harness names no single domain ---
DENY = re.compile(r"\b(trading|brokerage)\b", re.IGNORECASE)
for md in glob.glob(f"{ROOT}/.claude/**/*.md", recursive=True):
    with open(md, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if DENY.search(line):
                bad(f"{md}:{n}: domain-specific term in a domain-agnostic harness")

# --- token budget: the always-on surface is gated, not aspirational ---
# CLAUDE.md + rules/*.md are paid on every turn (token-economy.md). Budgets are
# words (whitespace-split — deterministic, no tokenizer dependency); ~0.75
# words/token puts the total near the README's ≈5k-token claim. Raising a
# budget is an explicit, reviewable act — that is the point.
# Calibrated 2026-08-01: CLAUDE.md 836, largest rule 679 (dev-process.md), total
# 4,252 by this metric (str.split() counts slightly above `wc -w`).
MAX_CLAUDE_MD_WORDS = 900
MAX_RULE_WORDS = 700
MAX_ALWAYS_ON_WORDS = 4500


def word_count(path: str) -> int:
    with open(path, encoding="utf-8") as fh:
        return len(fh.read().split())


always_on = word_count(f"{ROOT}/CLAUDE.md")
if always_on > MAX_CLAUDE_MD_WORDS:
    bad(f"CLAUDE.md: {always_on} words exceeds the {MAX_CLAUDE_MD_WORDS}-word budget")
for path in sorted(glob.glob(f"{ROOT}/.claude/rules/*.md")):
    w = word_count(path)
    always_on += w
    if w > MAX_RULE_WORDS:
        bad(f"{path}: {w} words exceeds the {MAX_RULE_WORDS}-word rule budget")
if always_on > MAX_ALWAYS_ON_WORDS:
    bad(
        f"always-on surface (CLAUDE.md + rules/) is {always_on} words — "
        f"exceeds the {MAX_ALWAYS_ON_WORDS}-word budget (token-economy.md)"
    )

# --- plugin packaging: manifests are valid JSON and wired scripts exist ---
plugin_manifest = f"{ROOT}/.claude/.claude-plugin/plugin.json"
marketplace = f"{ROOT}/.claude-plugin/marketplace.json"
plugin_hooks = f"{ROOT}/.claude/hooks/hooks.json"
for jf in (plugin_manifest, marketplace, plugin_hooks):
    if not os.path.isfile(jf):
        bad(f"plugin packaging: missing {os.path.relpath(jf, ROOT)}")
        continue
    try:
        with open(jf, encoding="utf-8") as fh:
            json.load(fh)
    except json.JSONDecodeError as exc:
        bad(f"plugin packaging: invalid JSON in {os.path.relpath(jf, ROOT)}: {exc}")

if os.path.isfile(plugin_hooks):
    with open(plugin_hooks, encoding="utf-8") as fh:
        ph = json.load(fh)
    for _event, entries in (ph.get("hooks") or {}).items():
        for entry in entries:
            for hook in entry.get("hooks", []):
                # The keel plugin's root is .claude/ (marketplace source "./.claude").
                m = re.search(
                    r"\$\{CLAUDE_PLUGIN_ROOT\}/(\S+\.sh)", hook.get("command", "")
                )
                if m and not os.path.isfile(os.path.join(ROOT, ".claude", m.group(1))):
                    bad(f"hooks.json: wired hook missing on disk: {m.group(1)}")

if offenders:
    print("Harness lint FAILED:")
    for o in offenders:
        print(f"  - {o}")
    sys.exit(1)
print("Harness lint OK.")

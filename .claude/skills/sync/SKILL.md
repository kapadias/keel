---
name: sync
disable-model-invocation: true
description: Reconcile drift across the five mirrors — issue tracker, docs/STATUS, git/PR, the .claude harness, and memory — so every record of the system agrees.
argument-hint: "[optional: the unit of work to reconcile; defaults to the current branch]"
model: sonnet
---

@docs/STATUS.md

Reconcile the five mirrors for: **$ARGUMENTS** (if empty, the current branch's work).

## Steps

Walk the five-mirror Definition of Done (full checklist: [`.claude/rules/sync.md`](../../rules/sync.md)) and fix any drift:

1. **Tracker** — issue in the right status, PR linked?
2. **Docs** — `docs/STATUS.md` current? Usage changed → README/docs updated? Non-trivial decision made → `/adr` filed?
3. **Git / PR** — branch + PR open, targeting `develop`, linked to the issue?
4. **Harness** — any agent/skill/command/rule/hook changed? → `.claude/README.md` and `CLAUDE.md` updated?
5. **Memory** — durable decisions (the _why_, rejected alternatives, learned invariants) captured to survive a context reset?
6. **Tests** — suite green? A task is never done in any mirror while tests are red.

## Output

A short report: each mirror marked ✅ in-sync or ✗ drifted-then-fixed, and anything that still needs a
human decision. Never leave one mirror claiming "done" while another contradicts it.

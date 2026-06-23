---
description: Reconcile drift across the five mirrors — issue tracker, docs/STATUS, git/PR, the .claude harness, and memory — so every record of the system agrees.
argument-hint: "[optional: the unit of work to reconcile; defaults to the current branch]"
---

Reconcile the five mirrors for: **$ARGUMENTS** (if empty, the current branch's work).

## Steps

Walk the Definition of Done (see [`.claude/rules/sync.md`](../rules/sync.md)) and fix any drift:

1. **Tracker** — is the issue in the right status, with the PR linked? Update it.
2. **Docs** — is `docs/STATUS.md` current? Did usage change (update the README/docs)? Was a non-trivial
   decision made (add an ADR via `/adr`)?
3. **Git / PR** — is there a branch + PR linked to the issue, targeting `develop`?
4. **Harness** — did any agent, skill, command, rule, or hook change? If so, do `.claude/README.md` and
   `CLAUDE.md` reflect it?
5. **Memory** — are the durable decisions (the *why*, the rejected alternatives, learned invariants)
   captured so they survive a context reset?
6. **Tests** — is the suite green? A task is never done in any mirror while tests are red.

## Output

A short report: each mirror marked ✅ in-sync or ✗ drifted-then-fixed, and anything that still needs a
human decision. Never leave one mirror claiming "done" while another contradicts it.

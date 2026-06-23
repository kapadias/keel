# 0003 — Progressive disclosure for the token economy

How Keel spends context: a tiny always-on core, depth on demand. Recorded as a load-bearing design
choice.

## Status

Accepted

## Date

2026-06-22

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

Context is a budget, and every always-on token is paid **on every turn** of every session. Standing
instructions are not free reference material — they are rent. A large, ever-present instruction file
also degrades the work: as a session fills, the model attends less reliably to any one line, and the
guidance that matters most is diluted by the guidance that rarely applies. Long sessions get worse, not
better, as the window crowds.

Keel needs depth — full TDD workflow, review checklists, debugging method, API-design guidance — without
paying for all of it on every turn.

## Options considered

1. **One big always-on instructions file.** Put every rule, workflow, and checklist into the
   always-loaded surface.
   - Everything is "available," but everything is also *always paid for*, every turn, forever. The
     window fills with mostly-irrelevant text, attention smears across it, and long sessions degrade.
     Worst cost/benefit ratio at scale.
2. **Progressive disclosure** (chosen). A **small, dense always-on core** (`CLAUDE.md` + the rules) that
   states the principles, the loop, and the boundaries — and nothing else. **Depth is pushed
   on-demand**: detailed procedures live in **skills** and **commands** loaded only when invoked, and
   broad investigation is delegated to **subagents** (notably the `explorer`, which sweeps files and
   returns *conclusions, not file dumps*) whose intermediate context never enters the main window.
   - Requires discipline about what earns always-on status, and a habit of delegating. But the standing
     cost is minimal, the relevant depth arrives exactly when needed, and the main window stays clear
     for the actual task.
3. **Minimal harness, no standing guidance.** Rely on the model's defaults; load nothing.
   - Cheapest in tokens, but throws away the discipline that is Keel's entire reason to exist —
     determinism, gating, and the loop. Cheap and unmoored.

## Decision

Keel uses **progressive disclosure**, encoded in
[`.claude/rules/token-economy.md`](../../.claude/rules/token-economy.md):

- The **always-on surface** (`CLAUDE.md` + rules) is kept small and dense — principles, the loop, the
  boundaries. Rules are written tight; growth is resisted.
- **Skills and commands** carry the depth and load only when invoked.
- **Subagents** absorb wide or noisy work; the `explorer` returns conclusions and citations, not raw
  file contents, keeping fan-out cost off the main context.
- New guidance defaults to a **skill or command**, not a new always-on rule. A rule must earn its place
  by being load-bearing on nearly every turn.

## Consequences

- The per-turn standing cost stays low, so long sessions hold up and the window stays available for the
  work in front of it.
- Contributors must decide *where* guidance lives (rule vs. skill vs. command vs. agent) — this is the
  intended discipline, documented in `CONTRIBUTING.md`.
- Investigation is delegated by default; the harness is built to spend a subagent rather than flood the
  main context.
- **Hard line:** token thrift is an optimization over *how guidance is delivered*, **never** a license
  to drop a check. Spending fewer tokens must **never** trade away a **test, a review, a validation, or
  a safety gate**. Those are lexically prior (see
  [ADR 0002](0002-llm-proposes-gates-decide.md)); economy operates strictly beneath them.

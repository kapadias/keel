# ADR 0008 — A decision ladder for solution size

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** Shashank Kapadia

## Context

Keel governs process — TDD, machine-checked review, five-mirror sync — with rigor, but it says almost
nothing about the **size** of the solution an agent should produce. `engineering.md`'s "Simplicity"
bullet is 42 words. In practice, agents over-build: hand-rolled stdlib logic, single-implementation
abstractions, avoidable dependencies, scaffolding "for later" that nobody asked for. A shortcut
deferred without a marker and a trigger tends to rot into "later means never" — there is no gate that
ever asks whether the deferred work should have happened by now.

Separately, a real gap exists under a plugin install: subagents received none of Keel's constitution.
`SessionStart`'s `additionalContext` is parent-only — it reaches the top-level conversation, never a
Task-spawned subagent. Verified against the Claude Code hooks reference: `SubagentStart` hooks "can
inject context into the subagent" via the same `additionalContext` mechanism, and a non-fork
subagent's initial context already includes "project rules" — so the gap is **plugin mode only**. A
standalone (copy-in) checkout loads `.claude/rules/` natively for every subagent; a plugin install
loads it for none.

## Options considered

1. **Do nothing.** Rejected: agents keep over-building with no vocabulary, no marker, and no gate to
   catch it, and plugin-mode subagents keep running with zero policy — a silent gap this project is
   built to prevent.
2. **Adopt a third-party "simplest solution" guidance plugin alongside Keel.** Rejected as the primary
   path. Its test rule — one runnable check, no frameworks — contradicts [testing.md](./../../.claude/rules/testing.md),
   which requires golden and property tests on the critical surface. Its output rule — code first, at
   most three lines — contradicts the Assumptions/Changed/Verified/Remaining-risk report this harness
   requires of every completed unit. And its intensity level is a flag file the model itself writes,
   with no deterministic gate in front of it — the same objection that already rejected persistent
   agent `memory:` state (ROADMAP WS3): free-text model output steering future model behavior, with
   nothing between it and the consequence.
3. **Port intensity modes (lite/full/ultra) into Keel.** Rejected as YAGNI: Keel's loop is always
   "full" — there is no lighter mode to select, so a mode switch would be state with no use.
4. **Absorb the ideas natively as Keel content and gates** (chosen). Take the parts that survive
   contact with Keel's existing principles — an ordered ladder, a marker convention for deliberate
   corners, a review lens for over-building, a root-cause discipline for bug fixes — and express each
   one as Keel content or a Keel gate, dropping anything that would create a second, ungated authority
   alongside the existing loop.

## Decision

A seven-rung decision ladder — YAGNI, already in this codebase, stdlib, native platform, installed
dependency, one line, minimum code — lives compactly in `rules/00-core.md`, the only rule file a
plugin install actually receives (via the `SessionStart` carrier), with full depth and worked examples
in the new `lean` skill. A Keel-native `debt: <ceiling>, <upgrade trigger>` comment marks a deliberate
corner; `check-debt.sh` fails a marker that has a ceiling but no upgrade trigger named after the comma,
and is wired into `/review` (gates the diff for newly introduced markers) and `/sync` (prints the
ledger of every marker in the tree). Over-engineering findings become a new `category: simplicity` in
the existing machine-checkable verdict contract (ADR-0005), capped at MEDIUM severity — a simplicity
finding never blocks a merge by itself. A `SubagentStart` hook carries `00-core.md` into every spawned
subagent, but **only in plugin mode**; a standalone checkout already loads rules natively for
subagents, so the hook emits nothing there and never pays twice.

### Design tensions resolved

| Topic              | Resolution                                                                                      | Why                                                                                                                     |
| ------------------ | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Tests              | Keel's TDD + golden/property tests win outright                                                 | Safety is lexicographically prior; the ladder shortens the solution, never the test                                     |
| Report             | Kept as Assumptions/Changed/Verified/Remaining-risk; skipped-and-when goes under Remaining risk | The report format is load-bearing; no fifth shape competes with it                                                      |
| Dependencies       | The existing ≥80% rule; always a library for parsing, dates, crypto, auth                       | Hand-rolling those is a security risk, not a flex                                                                       |
| Intensity          | None — not ported                                                                               | The loop is always "full"; a mode switch is unused state                                                                |
| Explanations       | Comment the why, ADRs, the audit trail                                                          | Matches [engineering.md](./../../.claude/rules/engineering.md) and [safety.md](./../../.claude/rules/safety.md) already |
| Review tags        | Carried by Keel's existing JSON verdict contract, with a MEDIUM cap                             | One schema, one decider — see ADR-0005                                                                                  |
| Bug fixes          | Root cause: grep every caller, fix the shared function once                                     | A per-caller patch leaves siblings broken; a shared fix is the smaller diff                                             |
| Subagent injection | Plugin mode only; a standalone checkout loads rules natively                                    | Do not pay for a gap that does not exist in that install mode                                                           |

## Consequences

- The always-on surface grows by about 80 words for the ladder in `00-core.md`, staying inside the
  3,700-word always-on budget.
- The ladder now exists in two places by design: the compact, always-on rungs in `00-core.md`, and the
  full depth in the on-demand `lean` skill. Because the two copies must stay in lockstep, the linter
  pins the seven rung keywords in both files and fails if either drifts from the other.
- `check-debt.sh` and the `SubagentStart` hook are both golden-tested, the same as every other gate in
  this harness — neither ships on the strength of a prose claim.
- The MEDIUM cap for `simplicity` findings is prose today, enforced by the reviewer prompt and the
  severity rubric rather than by `check-review.sh` itself (which validates `verdict` and `severity`,
  not `category` — see the amendment to ADR-0005). The upgrade path, if a simplicity finding is ever
  observed blocking a merge alone, is a category-aware cap inside `check-review.sh`.
- The expected saving from the ladder is an estimate, not a measurement, until it is tested inside
  Keel. The first ROADMAP WS7 behavioral eval should be a ladder on/off comparison on the same
  tickets, scoring source LOC, tokens, cost, and turns, behind a correctness and safety gate.

The source of these ideas is credited in `README.md`.

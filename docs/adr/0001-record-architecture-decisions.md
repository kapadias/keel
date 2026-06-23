# 0001 — Record architecture decisions

The first decision: to record decisions. After Michael Nygard, adapted to Keel.

## Status

Accepted

## Date

2026-06-22

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

Keel is a harness whose value is its discipline. The reasoning behind a rule, an agent boundary, or a
hook is often more load-bearing than the artifact itself — and that reasoning evaporates from chat
logs, commit messages, and memory. Without a durable record we re-litigate settled questions, and new
contributors (human or agent) cannot tell an intentional constraint from an accident.

We need a lightweight, version-controlled, append-only way to capture significant decisions next to the
code they govern.

## Options considered

1. **Do nothing.** Leave decisions in commit messages, PR threads, and chat history.
   - Cheap now. But the rationale is scattered, unsearchable, and lost on context reset; the
     "why" decays exactly when it is most needed.
2. **A single living design document.** One `DESIGN.md` edited over time.
   - Better than nothing, but mutation erases history: you cannot see what was decided *when*, what
     was rejected, or what superseded what. It drifts and rots into a wiki nobody trusts.
3. **Numbered, immutable ADRs under `docs/adr/`** (chosen). Each significant decision is a short,
   dated, numbered file with a fixed template; decisions are superseded, never edited.
   - Small per-decision cost, but a durable, ordered, greppable audit trail that travels with the
     repo and survives any context reset.

## Decision

We will record significant architectural decisions as numbered ADRs under `docs/adr/`, created with
the **`/adr`** command from the Keel template. Each ADR carries: **Status**, **Date**, **Deciders**,
**Context**, **Options considered** (≥3, including "do nothing"), **Decision**, and **Consequences**.
ADRs are immutable once accepted — a later decision supersedes an earlier one by reference rather than
by editing it. The index in `docs/adr/README.md` lists them all.

## Consequences

- The "why" behind load-bearing choices is durable, ordered, and searchable — and is one of the **five
  mirrors** kept in sync at the Definition of Done.
- Every significant decision pays a small writing tax. This is deliberate: the friction is the feature,
  forcing the trade-offs to be named before they are made.
- Reviewers and agents can cite an ADR to justify or challenge a change, raising the floor on design
  conversations.
- The set will grow; the `/adr` command and this index keep numbering and discovery cheap.

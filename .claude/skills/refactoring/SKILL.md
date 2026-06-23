---
name: refactoring
description: Apply when restructuring existing code without changing behavior — extracting, renaming, replacing conditionals, untangling a module. Use when the REFACTOR phase of the loop runs, or when deciding whether code is safe to refactor at all.
---

# Refactoring

Refactoring is changing the **shape** of code while its **behavior stays identical**. If behavior
changes, it is not a refactor — it is a feature or a fix, and it belongs in its own commit.

## The prime directive

**Tests stay green and unchanged throughout.** The test suite is the proof that behavior held. From
the first step to the last, every test that passed before passes after — and you did not edit the
tests to make that true. If a refactor forces a test change, one of two things is happening: the test
was coupled to internals (fix the test _first_, in a separate commit), or you are actually changing
behavior (stop — that's a different task).

**Never mix a refactor with a behavior change in the same commit.** A reviewer must be able to trust
that a "refactor" commit cannot have altered what the program does. Mixing the two destroys that
guarantee and makes the change un-reviewable and un-revertible.

## Tests-green as the safety net

You can only refactor safely under coverage. The suite is what lets you move fast — make a change,
run tests, and _know_ in seconds whether you broke something. No suite, no net, no speed.

Work in **small, reversible steps**. Extract one function, run tests, commit. Rename one symbol, run
tests, commit. If a step goes red, you revert _one small step_, not an afternoon. Big-bang rewrites
skip the net and accumulate undiagnosable breakage.

> "For each desired change, make the change easy (warning: this may be hard), then make the easy
> change." — Kent Beck

Often the feature you want is awkward because the current structure resists it. Refactor _first_ to
make room — as its own green-tested commit — _then_ add the behavior in the next commit. Two clean
steps beat one tangled one.

## Catalog of common refactors

The everyday moves are mechanical and local: **extract function**, **rename for intent**, **replace a
magic value with a named constant**, **introduce a parameter object**, **replace a conditional with a
lookup or polymorphism**, and **guard-clause early returns**. Each does one thing, keeps behavior
identical, and produces a diff small enough to hold in your head — so do one at a time. The full table
(when to reach for each, what it buys) with worked before/after examples lives in
[references/catalog.md](references/catalog.md).

## When NOT to refactor

- **No test coverage yet.** Refactoring blind is editing and hoping. Add **characterization tests**
  first — tests that pin current behavior _as-is_ (even if it's quirky) — then refactor under them.
- **On a hot deadline / incident path.** Ship the fix; refactor in a follow-up. Structure work and
  urgent work compete for the same attention and one will be done badly.
- **Speculative generality.** Don't add layers, hooks, or abstraction for a future that may never
  arrive. Refactor toward the code you have, not the code you imagine. The simplest structure that
  fits today's behavior is the goal.

A refactor that leaves the suite green, the diff small, and the next change easier has done its job.
See `.claude/rules/engineering.md`; the loop's REFACTOR phase is where this lives.

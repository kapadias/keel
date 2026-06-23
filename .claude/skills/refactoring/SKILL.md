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
was coupled to internals (fix the test *first*, in a separate commit), or you are actually changing
behavior (stop — that's a different task).

**Never mix a refactor with a behavior change in the same commit.** A reviewer must be able to trust
that a "refactor" commit cannot have altered what the program does. Mixing the two destroys that
guarantee and makes the change un-reviewable and un-revertible.

## Tests-green as the safety net

You can only refactor safely under coverage. The suite is what lets you move fast — make a change,
run tests, and *know* in seconds whether you broke something. No suite, no net, no speed.

Work in **small, reversible steps**. Extract one function, run tests, commit. Rename one symbol, run
tests, commit. If a step goes red, you revert *one small step*, not an afternoon. Big-bang rewrites
skip the net and accumulate undiagnosable breakage.

> "For each desired change, make the change easy (warning: this may be hard), then make the easy
> change." — Kent Beck

Often the feature you want is awkward because the current structure resists it. Refactor *first* to
make room — as its own green-tested commit — *then* add the behavior in the next commit. Two clean
steps beat one tangled one.

## A catalog of common refactors

| Refactor | When | What it buys |
|---|---|---|
| **Extract function** | A block needs a comment to explain it, or is duplicated | A name replaces the comment; the duplication collapses |
| **Rename for intent** | A name lies, abbreviates, or under-specifies | The code reads as the domain; fewer "what is this?" stalls |
| **Replace magic value with named constant** | A literal `86400` / `"ADMIN"` appears in logic | Intent is explicit; the value changes in one place |
| **Introduce parameter object** | A call passes the same 3–4 args everywhere | Cohesion; new related fields don't churn signatures |
| **Replace conditional with polymorphism / lookup** | A `switch`/`if-elif` on a type or key recurs | New cases extend a table or type, not edit a ladder |
| **Guard-clause early returns** | Deep nesting from validation pyramids | The happy path flattens; preconditions read top-down |

Each is mechanical and local. Do one at a time; keep the diff small enough to hold in your head.

```text
# before: nested, intent buried
def price(o):
    if o.valid:
        if o.qty > 0:
            return o.qty * o.unit
    return 0

# after: guard clauses + intent — same behavior, tests untouched
def price(o):
    if not o.valid:    return 0
    if o.qty <= 0:     return 0
    return o.qty * o.unit
```

## When NOT to refactor

- **No test coverage yet.** Refactoring blind is editing and hoping. Add **characterization tests**
  first — tests that pin current behavior *as-is* (even if it's quirky) — then refactor under them.
- **On a hot deadline / incident path.** Ship the fix; refactor in a follow-up. Structure work and
  urgent work compete for the same attention and one will be done badly.
- **Speculative generality.** Don't add layers, hooks, or abstraction for a future that may never
  arrive. Refactor toward the code you have, not the code you imagine. The simplest structure that
  fits today's behavior is the goal.

A refactor that leaves the suite green, the diff small, and the next change easier has done its job.
See `.claude/rules/engineering.md`; the loop's REFACTOR phase is where this lives.

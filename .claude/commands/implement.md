---
description: Implement code against an existing failing test or a clear spec — minimal, typed, reviewable, matching the surrounding style. Use when the test/spec already exists.
argument-hint: "[what to implement; assumes a failing test or clear spec exists]"
---

Implement: **$ARGUMENTS**

## Steps

1. **Anchor on the gate.** Confirm a failing test or unambiguous spec exists. If it does not, stop and
   run `/tdd` first — production logic without a test is not allowed (see
   [`.claude/rules/dev-process.md`](../rules/dev-process.md)).
2. **Read the neighborhood.** Read the specific spans you will touch and the patterns around them (use
   `explorer` for anything broad). Match local naming, error handling, and idiom.
3. **Write the minimal code** that makes the test pass. Follow
   [`.claude/rules/engineering.md`](../rules/engineering.md): typed at boundaries, validate untrusted
   input at the edge, pure where it matters, fail loud in the critical path, no secrets, no `print`.
4. **Refactor** with tests green: remove duplication, clarify names, keep the diff small and reviewable.
5. **Verify locally:** run lint + type-check + tests. Leave the tree green.

## Guardrails

- Do not run irreversible or outward-facing commands (deploy, force-push, delete, migrate) without
  explicit authorization — see [`.claude/rules/safety.md`](../rules/safety.md).
- Do not silently swallow errors in code that touches money, data, or state.

## Output

The diff, confirmation the suite is green, and a handoff to `/review`.

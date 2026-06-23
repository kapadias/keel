---
description: Run the test-driven cycle — RED (failing test) → GREEN (minimal code) → REFACTOR — for a unit of behavior. The default way to build anything in Keel.
argument-hint: "[the behavior to build, test-first]"
---

Build, test-first: **$ARGUMENTS**

## The cycle

1. **RED — pin the behavior.** Have `test-engineer` write the smallest test that fails for the right
   reason and captures the desired behavior. **Confirm it fails** before writing any production code —
   a test that passes immediately proves nothing. For core/critical logic, include a **golden** test
   (exact oracle value) and a **property** test (invariant over generated inputs). See
   [`.claude/rules/testing.md`](../rules/testing.md).
2. **GREEN — make it pass.** Have `implementer` write the **minimal** code that passes the test. No
   speculative generality, no extra features. Run the test; see it pass.
3. **REFACTOR — clean up.** With tests green as the safety net, improve names, remove duplication, and
   make the change match the surrounding code. Re-run the suite after each refactor.

## Rules

- No production logic without a test that would have failed before it.
- Do not weaken or delete a test to get to green. If a test is wrong, fix it deliberately and say why.
- Keep the working tree green at each step. Run lint + type-check + tests before handing off.

## Output

The new/changed tests, the implementation, and a one-line note that the full suite is green. Hand off to
`/review` when the behavior is complete.

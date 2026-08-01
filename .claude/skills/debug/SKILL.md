---
name: debug
description: Root-cause a failure — reproduce deterministically, isolate by bisection, fix the cause (not the symptom), and leave a regression test behind.
argument-hint: "[the failure: a test name, error message, or wrong behavior]"
model: opus
---

Debug: **$ARGUMENTS**

## Steps (hand to `debugger` for anything non-obvious)

1. **Reproduce.** Get a deterministic repro — ideally a failing test. If none exists, write one now; it
   becomes the regression test. A bug you cannot reproduce, you cannot claim to have fixed.
2. **Isolate.** Form a hypothesis and bisect — recent diffs, inputs, the code path, git history. Read
   the stack trace and the actual values; trust evidence over intuition. Use `explorer` to locate
   suspects without bloating this thread.
3. **Diagnose.** State the root cause in one sentence: _the bug is X, which causes Y under condition Z._
4. **Fix minimally.** Change the cause, not the symptom. Keep the diff small. Do **not** broaden a
   `catch`, loosen a check, or weaken a test to make red go away — that hides the bug (see
   [`.claude/rules/safety.md`](../../rules/safety.md)).
5. **Prove it.** The regression test passes, the full suite stays green, and nothing was masked.

## Output

The root-cause sentence, the minimal fix, and the regression test that now guards it.

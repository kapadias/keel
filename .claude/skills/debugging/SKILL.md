---
name: debugging
description: Apply when chasing a bug, regression, or failing test to root cause — building a deterministic repro, isolating by bisection, stating the cause, fixing minimally, and proving the fix. Use when `/debug` runs or the debugger agent engages.
---

# Debugging

Find the cause, not a quieter symptom. A bug you patched without understanding is a bug you will
meet again under a worse condition. **Trust evidence over intuition** — the code does what it does,
not what you remember writing.

## The method: Reproduce → Isolate → Diagnose → Fix → Prove

### 1. Reproduce

Make it happen **on demand**. An intermittent bug you cannot trigger is a bug you cannot fix or
verify. Drive the repro down to the smallest deterministic input. Ideally, **encode it as a failing
test** — that test is now both your reproduction and your future regression guard. If you can't
reproduce it, you're not debugging yet; you're guessing.

### 2. Isolate

Form a **hypothesis**, then run an experiment that can falsify it. Binary-search the fault:

- **History:** `git bisect` across commits — "what changed since it last worked?" is the single most
  productive question. Bisect finds the commit in `log₂(n)` steps. The bundled helper
  `scripts/bisect.sh` automates the whole run: `bisect.sh <good-ref> <test-command...>`, where the
  test command exits 0 when the bug is **absent** and non-zero when **present**.
- **Input:** halve the failing input until the minimal trigger remains.
- **Code path:** disable/short-circuit halves of the pipeline to localize the stage.

Change **one variable at a time**. If you change three things and it works, you've learned nothing.

### 3. Diagnose

State the root cause in **one sentence** before touching the fix:

> "The bug is _X_ (a stale cache key), which causes _Y_ (a deleted record reappears) under condition
> _Z_ (two writes within the TTL window)."

If you can't fill in X, Y, and Z, you haven't found it — keep isolating. A fix applied before
diagnosis is a coin flip.

### 4. Fix minimally

Fix the **cause, not the symptom**, with the **smallest diff** that removes it. Don't refactor
surrounding code in the same change — a fix commit should be reviewable as exactly the fix. If the
real fix is large, note it and do the surgical version now; schedule the rest.

### 5. Prove

- The regression test from step 1 now **passes**.
- The **full suite is green** — you fixed it without breaking a neighbor.
- **Nothing was masked.** You didn't make the failure invisible; you made it not happen.

## Reading a stack trace

Read it as a timeline: classify by the exception type, find the throw site, then trace the bad value
**backward** to its origin — the throw is the symptom, the line that set up the value is the cause.
Ordering and chaining differ per language (Python fails at the bottom; Java/JS at the top); see
[references/stack-traces.md](references/stack-traces.md) for worked examples across Python, the JVM,
and async Node.

## Anti-patterns

- **Symptom-patching.** Adding a null-check where it blew up instead of asking why the value was
  null. The cause moves downstream and returns.
- **Broadening a catch.** Wrapping a wider `try` to make an exception disappear hides the next bug
  too. Catch narrowly, at the layer that can actually handle it.
- **Silencing what you don't understand.** Swallowing an error or downgrading a log to make red go
  away is hiding a fire, not putting it out. (`.claude/rules/safety.md` — never fail open.)
- **Weakening a test to go green.** Loosening an assert or deleting a case to pass is sabotage of the
  one thing protecting capital. The test was right; the code is wrong.
- **Debugging by random edit.** Changing things hoping the symptom shifts. Without a hypothesis
  you're not learning — you're rolling dice and corrupting state.

Route through the `debugger` agent and `/debug`. When the cause is found, the regression test ships
**with** the fix — that's how the same bug never bills you twice.

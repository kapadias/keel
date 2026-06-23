---
name: code-review
description: Apply when reviewing a diff or PR — triaging findings by severity, deciding what to flag versus let go, writing actionable findings, or rendering a merge verdict. Use when `/review` runs or the code-reviewer / security-reviewer agents engage.
---

# Code Review

Review as an adversary, report as an ally. Your job is to find the defect that reaches production,
not to repaint the bikeshed. **Safety is lexicographically prior to speed** — a fast PR that fails
open is a defect, not a feature.

## Severity rubric

| Severity | What belongs here |
|---|---|
| **CRITICAL** | Trust-boundary breach (unvalidated input reaching a sink, authz bypass, injection); silent failure in money/data/state; **fail-open** behavior. These block merge automatically. |
| **HIGH** | Correctness bug on a real path; missing/meaningless tests on critical logic; a swallowed error that hides failure; secret or PII in logs. Block merge. |
| **MEDIUM** | Weak error handling, fragile assumption, missing edge case off the hot path, unclear contract. Fix when feasible. |
| **LOW** | Local readability, naming, minor duplication. Optional. |

Auto-CRITICAL, no debate: a **trust-boundary breach**, a **silent failure in money / data / state**,
or any path that **fails open**. If you find one, the verdict cannot be safe-to-merge until it is gone.

## Category checklist

- **Correctness & boundaries.** Does it do what the change claims? Is untrusted input validated *at
  the edge* before it is trusted? Are illegal states reachable? (`.claude/rules/boundaries.md`)
- **Tests present & meaningful.** New logic has tests that would *fail without the change*. Check the
  asserts are real, not vacuous. No test → treat as incomplete.
- **Error handling / fail-closed.** On error, does it deny, halt, or roll back — never proceed? Are
  errors typed and propagated, not swallowed? (`.claude/rules/safety.md`)
- **Secrets & logging.** No keys/tokens/PII in code, logs, or traces. No secret in a fixture.
- **Reproducibility.** No wall-clock or global RNG in decision logic; same inputs → same outputs.
- **Style fit.** Matches the *local* idiom. Consistency with the file beats your personal preference.

## Writing a finding

One finding = **`path:line` + the problem in one sentence + a concrete fix.** Make it cheap to act on.

> `payments/refund.py:88` — CRITICAL: refund amount comes straight from the request body with no
> bound check; a negative or oversized value posts a fraudulent credit. Validate `0 < amount <=
> original_charge` at the handler edge and reject otherwise.

Bad finding: "error handling could be improved here." No location, no defect, no fix — noise.

## Reviewing as an adversary

Assume the diff is hiding a bug and go find it. Trace the **untrusted path**: where does external
input enter, and what is the first place it is trusted without a check? Ask the failure questions —
*what happens when this is null / negative / huge / concurrent / retried / times out?* Read the test
the author *didn't* write. Confirm fail-closed on the error branch, not just the happy path.

## What NOT to flag

Signal dies in a flood of nits. Skip:

- **Subjective style** a formatter/linter already owns, or that merely differs from your taste.
- **Restyling that fights the local idiom** — rewriting working code into your preferred shape.
- **Speculative "what if we later need…"** generality the change doesn't require.

Prefer **fewer, high-confidence findings** over a long list. If you are unsure it's a real defect,
either verify it or mark it explicitly as a question, not a blocker. Ten weak findings bury the one
that matters.

## Verdict

Close with an explicit verdict and a grouped list:

```
VERDICT: CHANGES REQUIRED  (or: SAFE TO MERGE)
CRITICAL: <n>   HIGH: <n>   MEDIUM: <n>   LOW: <n>
- [CRITICAL] path:line — one-line problem + fix
- [HIGH]     path:line — ...
```

**Safe-to-merge once every CRITICAL and HIGH is addressed.** MEDIUM/LOW may ship with a follow-up.
Hand security-sensitive diffs to the `security-reviewer`; the deterministic gate decides, not the
author's confidence.

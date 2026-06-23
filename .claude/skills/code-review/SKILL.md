---
name: code-review
description: Apply when reviewing a diff or PR — triaging findings by severity, deciding what to flag versus let go, writing actionable findings, or rendering a merge verdict. Use when `/review` runs or the code-reviewer / security-reviewer agents engage.
---

# Code Review

Review as an adversary, report as an ally. Your job is to find the defect that reaches production,
not to repaint the bikeshed. **Safety is lexicographically prior to speed** — a fast PR that fails
open is a defect, not a feature. The reviewer proposes findings; a deterministic gate decides the
merge (see "Verdict" below).

## Severity, in one breath

**CRITICAL** = trust-boundary breach, silent failure in money/data/state, or fail-open — blocks merge,
no debate. **HIGH** = a correctness bug on a real path, missing tests on critical logic, a swallowed
error, or a secret/PII in logs — blocks merge. **MEDIUM** = weak handling or an edge case off the hot
path — fix when feasible. **LOW** = readability/naming — optional. Full calibration, the auto-CRITICAL
list, and how severity maps to the gate: [`references/severity-rubric.md`](references/severity-rubric.md).

## Category checklist

- **Correctness & boundaries.** Does it do what the change claims? Is untrusted input validated _at
  the edge_ before it is trusted? Are illegal states reachable? (`.claude/rules/boundaries.md`)
- **Tests present & meaningful.** New logic has tests that would _fail without the change_. Check the
  asserts are real, not vacuous. No test → treat as incomplete.
- **Error handling / fail-closed.** On error, does it deny, halt, or roll back — never proceed? Are
  errors typed and propagated, not swallowed? (`.claude/rules/safety.md`)
- **Secrets & logging.** No keys/tokens/PII in code, logs, or traces. No secret in a fixture.
- **Reproducibility.** No wall-clock or global RNG in decision logic; same inputs → same outputs.
- **Style fit.** Matches the _local_ idiom. Consistency with the file beats your personal preference.

## Reviewing as an adversary

Assume the diff is hiding a bug and go find it. Trace the **untrusted path**: where does external
input enter, and what is the first place it is trusted without a check? Ask the failure questions —
_what happens when this is null / negative / huge / concurrent / retried / times out?_ Read the test
the author _didn't_ write. Confirm fail-closed on the error branch, not just the happy path.

## Writing a finding

One finding = **`path:line` + the problem in one sentence + a concrete fix.** Make it cheap to act on.

> `payments/refund.py:88` — CRITICAL: refund amount comes straight from the request body with no
> bound check; a negative or oversized value posts a fraudulent credit. Validate `0 < amount <=
original_charge` at the handler edge and reject otherwise.

Bad finding: "error handling could be improved here." No location, no defect, no fix — noise.

## What NOT to flag

Signal dies in a flood of nits. Skip subjective style a formatter/linter already owns, restyling that
fights the local idiom, and speculative "what if we later need…" generality the change doesn't require.
Prefer **fewer, high-confidence findings**. If unsure it's a real defect, mark it as a _question_, not
a blocker — ten weak findings bury the one that matters.

## Verdict — emit JSON, let the gate decide

Close by emitting the structured verdict — schema:
[`templates/verdict.json`](templates/verdict.json). Each finding is one object
(`severity`, `path`, `line`, `category`, `issue`, `fix`); the top-level `verdict` is
`approve` or `request_changes`.

Pipe it through the deterministic gate, which **exits 1 on `request_changes` or any CRITICAL/HIGH**:

```bash
your-review-step | .claude/skills/code-review/scripts/check-review.sh
# or:               .claude/skills/code-review/scripts/check-review.sh review.json
```

This is the boundary doing its job (`.claude/rules/boundaries.md`): the LLM proposes severities; the
script renders the merge decision. **Safe-to-merge once every CRITICAL and HIGH is addressed**;
MEDIUM/LOW may ship with a follow-up. Hand security-sensitive diffs to the `security-reviewer`.

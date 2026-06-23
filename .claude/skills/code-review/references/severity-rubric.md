# Severity Rubric — code review

The severity decides the gate. `check-review.sh` blocks merge on **CRITICAL** or **HIGH** (and on a
`request_changes` verdict). MEDIUM/LOW never block — they ship with a follow-up. So severity is not a
mood; it is a load-bearing classification. Calibrate it deliberately.

## The four levels

| Severity     | What belongs here                                                                                                                                                             | Gate                                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **CRITICAL** | Trust-boundary breach (unvalidated input reaching a sink, authz bypass, injection); silent failure in money/data/state; **fail-open** behavior; secret committed to the repo. | Blocks merge. Non-negotiable.                         |
| **HIGH**     | Correctness bug on a real, reachable path; missing/meaningless tests on critical logic; a swallowed error that hides failure; secret or PII in logs/traces.                   | Blocks merge.                                         |
| **MEDIUM**   | Weak error handling, fragile assumption, missing edge case **off** the hot path, unclear or undocumented contract, a race that needs an unlikely interleaving.                | Fix when feasible; may ship with a tracked follow-up. |
| **LOW**      | Local readability, naming, minor duplication, a comment that lies.                                                                                                            | Optional. Never block on it.                          |

## Auto-CRITICAL — no debate

If you find any of these, the verdict is `request_changes` until it is gone. Do not negotiate them
down to HIGH to unblock a deadline:

- **Trust-boundary breach** — external input (request body, query param, file, another service, LLM
  output) reaches a sink (SQL, shell, filesystem path, `eval`, a deploy/payment/delete) without being
  validated and bounded at the edge. (`.claude/rules/boundaries.md`)
- **Silent failure in money / data / state** — an error in a path that touches funds, persistence, or
  irreversible action is swallowed, logged-and-continued, or clamped-and-proceeded instead of halting.
- **Fail-open** — on error or ambiguity the code proceeds with the privileged/destructive default
  instead of denying. (`.claude/rules/safety.md`)
- **Secret in the diff** — a key, token, password, or credential committed to the repo (even in a
  test fixture or an example). Flag it, and the secret must be rotated, not just deleted.

## Calibration — the questions that set severity

Severity is a function of **blast radius × reachability × reversibility**:

- **Is the bad path reachable by untrusted input?** Reachable → at least HIGH; reachable _and_ a sink
  → CRITICAL. A defect behind an internal-only, authenticated, rarely-hit path is lower.
- **What does it touch?** Money, auth, user data, or an irreversible/outward-facing action raises the
  floor. Display/glue code lowers it.
- **Does it fail closed or open?** Fail-open is the multiplier that turns a MEDIUM into a CRITICAL.
- **Is there a test that would have caught it?** Missing tests on critical logic is itself HIGH —
  untested survival-critical code is incomplete, not merely thin.

When genuinely unsure whether something is a real defect, **do not pad the count** — mark it as a
question, not a blocker. Ten weak HIGHs bury the one that matters and train authors to ignore the gate.

## Severity → schema → gate

Each finding becomes one object in `findings[]` of
[`../templates/verdict.json`](../templates/verdict.json): `severity`, `path`, `line`, `category`,
`issue`, `fix`. The reviewer (human or agent) emits that JSON; `../scripts/check-review.sh` reads it
and renders the deterministic verdict. The LLM proposes the severities; the script decides the merge.
That is the boundary working as designed — see `.claude/rules/boundaries.md`.

# 2026-09-23 — Keel vs a bare agent

The number a landing page owes its reader: the same model on the same tasks with **no harness at
all** versus Keel. The earlier evals ([v1](2026-09-22-ladder.md), [v2](2026-09-22-ladder-v2.md))
measured the decision ladder in isolation; this one measures the harness.

## Method

Same six trap tasks and scratch project as v2 (date picker, debounce, id, retry, config,
snapshot). Two arms: `none` = no `.claude/`, no `CLAUDE.md`, the prompt's "Run /review before
you finish" replaced by "Review your change before you finish"; `keel` = the harness with
`/review` forced. Claude Sonnet, headless, two runs per task per arm (n = 12 per arm). The
`keel` rows are the v2 `after` runs reused unchanged, from the archived commit `04f0772`; only
the `none` arm was newly run for this eval. Scored on a hidden check the agent
never saw, whether a dependency file was created, whether any test file was left behind, source
lines added (tests excluded), cost and wall time. Rows:
[`2026-09-23-bare-vs-keel-runs.tsv`](2026-09-23-bare-vs-keel-runs.tsv).

## Result

| arm            | correct | wrote tests | dependency files | src LOC median (mean) | cost mean | wall mean |
| -------------- | ------: | ----------: | ---------------: | --------------------: | --------: | --------: |
| **bare agent** |   12/12 |        0/12 |                0 |             6.5 (7.9) |     $0.13 |      28 s |
| **Keel**       |   12/12 |       12/12 |                0 |           16.5 (21.7) |     $2.82 |     429 s |

For the record, the same harness without the ladder, the `lean` skill and the review-inflation
rule (the v2 `before` arm) scored 10/12, one dependency file, a 22-line median and $3.18 per run.

## Reading it honestly

- **The bare agent is not the over-builder these tasks were designed to catch.** Sonnet with no
  guidance reached for `<input type="date">`, a closure, `uuid4`, `os.environ`, `copy.deepcopy`
  on its own — 12/12 correct, no dependency, a median of 6.5 lines, thirteen cents. The
  "date picker → 404 lines" failure mode belongs to weaker or older models than the one used here.
- **What the bare agent never did, in 12 runs, is leave a test.** Not one. It also never updated
  a status doc, never had its change reviewed by anything but itself, and would have committed
  to `main` or pasted a key with nothing to stop it — none of which these tasks exercised.
- **Keel's cost is the loop, not the ladder.** Twenty times the money and fifteen times the
  wall time buy a failing test first, two independent reviewers, a machine-checked verdict and a
  synced status doc on every one of the twelve runs. The extra lines are mostly what review asked
  for; the ladder pulled the median from 22 to 16.5 lines against the same harness without it.
- **So the pitch cannot be "less code."** It is: every change ships with proof. Whether that is
  worth 20× per change depends on what a wrong "done" costs you. For a ledger, yes. For a
  throwaway script, no — and Keel's `/fix` fast lane exists for the middle.

## What to run next

Tasks where a bare agent actually fails: a fixture that needs a secret, a change that should not
land on `main`, a bug whose "fix" hides the error, a refactor with no coverage — the failure
modes Keel's gates are for. Score "did it get caught," not lines.

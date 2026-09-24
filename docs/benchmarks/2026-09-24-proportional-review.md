# 2026-09-24 — Proportional review: what it saved, and what it did not

The [bare-agent eval](2026-09-23-bare-vs-nonna.md) found a harnessed run cost about twenty times a
bare one, and that 62% of that spend went to two review subagents on the deep tier. ADR-0009 answered
with review sized by a script, the cheaper tier for `/review` and `/fix`, and a gate-printed list of
optional findings. This eval re-runs the same six small tasks to see what that bought.

## Method

Same scratch project, prompts ("Run /review before you finish") and flags as the bare-agent eval.
Claude Sonnet, headless, two runs per task per arm. Arms, by the harness commit they ran:

- `none`: no harness (the 2026-09-23 rows, reused).
- `04f0772`: the harness before ADR-0009 (the 2026-09-23 rows, reused).
- `478db09`: ADR-0009 as first committed.
- `4f4d5af`: this branch's head, after the review fixes to `review-lanes.sh`.

Two hidden checks were unfair and were fixed before scoring every arm again: the debounce check
could not load an ES module, and the config check hard-coded an environment variable name the prompt
never gave. Each fixed check passes known-good and fails known-bad solutions. Raw rows:
[`2026-09-24-proportional-review-runs.tsv`](2026-09-24-proportional-review-runs.tsv); the lane
each `4f4d5af` run took: [`2026-09-24-proportional-review-lanes.tsv`](2026-09-24-proportional-review-lanes.tsv).

## Result

| arm       | correct | left a test | src LOC median (mean) | mean cost | mean wall | deep-tier share of cost |
| --------- | ------: | ----------: | --------------------: | --------: | --------: | ----------------------: |
| `none`    |   12/12 |        0/12 |             6.5 (7.9) |     $0.13 |      28 s |                       — |
| `04f0772` |   12/12 |       12/12 |           16.5 (21.7) |     $2.82 |     429 s |                     62% |
| `478db09` |   12/12 |       12/12 |           26.5 (31.6) |     $1.86 |     349 s |                     33% |
| `4f4d5af` |   11/12 |       12/12 |           22.0 (21.9) |     $1.96 |     367 s |                     35% |

## Reading it honestly

- **Cost fell by about a third, from the model tier alone.** The deep tier's share dropped from 62%
  to about a third because `/review` and the light-lane reviewer moved to the cheaper model.
- **The light lane never engaged, so its saving is still unmeasured.** In this benchmark the harness
  is copied into each run and never committed, so `review-lanes.sh` saw an untracked `.claude/`
  directory, a risky path, and sent every run to the full lane with security. That is correct
  behaviour for a diff that really changes the harness, and an artefact here: in a real repository
  `.claude/` is committed once and absent from later diffs. The two rates tasks (env reads, network
  calls) went to security review for a real reason. The next eval commits the harness before the
  run.
- **More reviewers, not fewer.** 39 reviewer spawns across 12 runs at `4f4d5af` against 30 at
  `04f0772`: re-reviews after fixes. Cheaper each, still many.
- **Lines went up.** The median rose from 16.5 to 22. The largest cases are review asks that are
  arguably right: a date-of-birth check computed "today" in UTC, which lets users west of UTC pick
  tomorrow, and a configurable URL grew validation for a missing placeholder. Neither was marked
  optional by the reviewers, so the new optional-findings list did not trim them.
- **One miss.** A retry run made the callers robust instead of `fetch_rates()` itself; the check
  calls `fetch_rates()`. The prompt allows both readings. It counts as a miss.
- **One run skipped the script.** It read the skill and launched a single reviewer without running
  `review-lanes.sh`. The gate on the verdict still ran; the sizing did not.
- **Small numbers.** Two runs per task.

## What to run next

Commit the harness in the scratch project before each run, so the lane decision sees only the task's
diff. Then the light lane's share of runs, and its cost, can be measured.

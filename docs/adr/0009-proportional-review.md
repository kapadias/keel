# ADR 0009 — Proportional review, sized by script

- **Status:** Accepted
- **Date:** 2026-09-24
- **Deciders:** Shashank Kapadia

## Context

A benchmark of six small tasks ([2026-09-23](../benchmarks/2026-09-23-bare-vs-nonna.md)) put a
harnessed run at about twenty times the cost of a bare agent. A breakdown of the per-model usage in
those runs found that 63% of the spend went to the two review subagents, both on the deep tier at
high effort, and not to implementation. `/review` itself was also on the deep tier, though it only
dispatches reviewers and runs scripts.

The security reviewer's trigger was prose the model judged: "touches auth, data, money, input
handling, or anything outward-facing". Nearly every change touches input handling, so the model said
yes nearly every time. That is the very thing [ADR 0002](0002-llm-proposes-gates-decide.md) forbids:
a model deciding a gate by judgement.

## Decision

1. **`review-lanes.sh` decides how much review a diff buys** and prints `lane=light|full` and
   `security=yes|no`.
   - `lane=light` iff `check-trivial.sh` qualifies the delta: one `code-reviewer` on the cheaper
     tier.
   - `security=yes` iff a changed path or an added line matches a risky pattern: auth, secrets,
     money, migrations, deploy, shell/exec, SQL, deserialization, outward network calls, env reads,
     or `NONNA_CRITICAL_PATHS`. Test-only and markdown lines alone do not trigger it.
   - Any ambiguity (no repo, bad base, missing classifier) answers `full` and `yes`.
2. **`/review` runs on the cheaper tier.** It dispatches; the reviewers keep their own tiers.
3. **`/fix` runs its single reviewer on the cheaper tier.** A diff the fast-lane classifier accepts
   does not need the deep one.
4. **Start small.** A change that looks small begins in `/fix`, and the classifier moves it to the
   full loop when it outgrows the lane.
5. **Off the critical surface, one test is enough**: one that would have failed before the change.
   Golden plus property tests stay mandatory on the critical surface.

6. **Review asks stop inflating code.** A finding may carry `adds_code` and `failing_input`. On an
   approving verdict, `check-review.sh` lists each adds-code finding with no failing input as
   `optional:`, and the implementer leaves it (a `debt:` marker, not code). This turns the
   review-inflation rule from prose into script output.

`check-review.sh`'s exit codes are unchanged and still decide merge-readiness on every verdict. The linter blocks a
`/review` that stops invoking `review-lanes.sh`.

## Consequences

- Small, low-risk diffs pay for one cheaper review instead of two deep ones.
- The security reviewer runs on evidence in the diff, not on the model's reading of the change. A
  pattern list can miss a risky change phrased in a new way. The mitigation is that the list errs
  broad, `NONNA_CRITICAL_PATHS` extends it per project, and the code reviewer still reviews every diff.
- The deep tier stays where it earns its cost: full-lane code review and every security review.

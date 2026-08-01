# Rule: Safety & Blast Radius

Some mistakes are recoverable; some are not. This rule is about the second kind. Survival is
lexicographically prior to speed: you cannot iterate from a deleted database or a leaked key.

## Classify the blast radius before acting

Before any action, ask: **is this reversible, and how far does it reach?**

- **Reversible & local** (edit a file, write a test, run a read-only query): proceed.
- **Reversible but wide** (a broad refactor, a dependency bump): proceed, but verify and keep the diff
  reviewable.
- **Irreversible or outward-facing** (deploy, `git push --force`, delete data, drop a table, publish a
  package, send an email, rotate a credential, charge a card): **stop and confirm** unless you have
  explicit, current authorization. Approval for one such action does not extend to the next.

## Gates on risk-increasing actions

- **Pre-action checks are deterministic and blocking.** No deploy/migration/delete runs that fails its
  checks. Risk-_reducing_ actions (rollback, revert, halt) may be automatic; risk-_increasing_ actions
  are gated.
- **Idempotency.** Operations that may be retried (submissions, webhooks, jobs) use stable keys so a
  retry never double-applies.
- **The external system is the source of truth.** Reconcile local state against the real system (the
  broker, the database, the API) and **halt on unexplained divergence** rather than trusting a local
  cache. Do not assume a write succeeded — confirm it.

## Fail closed

When a dependency is down, a check is ambiguous, or input is malformed, default to the **safe**
outcome: do nothing, or do the defensive thing. Never fail open into "proceed anyway." A false stop
costs time (recoverable). A missed stop can cost the system (terminal). The asymmetry decides ties.

## Human-in-the-loop — non-negotiable gates

The list is in [00-core.md](./00-core.md). What it means in practice: the human sees the diff, the
blast radius, and the rollback path _before_ approving — an approval given without those is a
rubber stamp, and approval for one action never extends to the next.

## Secrets & audit

- **No secrets in code, logs, traces, or prompts.** They live in a secret manager or git-ignored
  `.env` (read-denied in `.claude/settings.json`). If a secret is exposed, rotate it — do not just
  delete the commit.
- **Keep an auditable trail** for consequential actions (deploys, migrations, approvals): what changed,
  when, by whom, and why. You should be able to answer "what happened?" after the fact.

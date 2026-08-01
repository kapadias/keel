# Rule: Core — the non-negotiables

The constitution. Every other rule elaborates one of these; none contradicts them. This file is also
what a plugin install receives through `SessionStart` (ADR-0007), so it must stand alone.

## The three principles

1. **The LLM proposes; deterministic gates decide.** An LLM may read, hypothesize, draft, and
   explain. Tests, types, linters, schema checks, and human review decide what merges or acts. Never
   act on free-text model output that touches production, money, user data, or an irreversible
   action without a gate between it and the consequence. → [boundaries.md](./boundaries.md)
2. **Safety is lexicographically prior to speed.** Risk-_reducing_ actions (revert, halt, roll back,
   narrow scope) may be automatic. Every risk-_increasing_ action passes a gate or a human. When the
   safety layer and the fast layer disagree, safety wins. → [safety.md](./safety.md)
3. **Context is a budget.** Keep the always-on surface tiny; load depth on demand; delegate fan-out
   reading to subagents and keep the conclusion, not the dump. Thrift never buys out a test, a
   review, a validation, or a gate. → [token-economy.md](./token-economy.md)

## The loop

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

Do not skip stages. One exception: a trivial, reversible fix may take the `/fix` fast lane —
`check-trivial.sh` decides eligibility, never prose. → [dev-process.md](./dev-process.md)

## Never

- Commit or push to `main`/`develop`, or force-push. (`guard-branch.sh` blocks it.)
- Put a secret in code, logs, traces, or prompts. (`secret-scan.sh` blocks it.)
- Mark work done — in a tracker, in `STATUS.md`, or in a PR — with failing tests.
- Ship production logic with no test that would have failed before it.
- Override a gate's verdict with your own judgment.

## A human approves

First promotion to production · anything that widens blast radius (raising a limit, broadening a
permission, deleting at scale) · overriding a safety gate · onboarding an external dependency with
access to data or money.

## Done means the mirrors agree

Tracker · `docs/STATUS.md` · docs/ADR · branch + PR · the `.claude/` index · memory. Merged code with
a drifted mirror is a silent lie about the state of the system. → [sync.md](./sync.md)

Branch `feature|fix|chore|refactor/<id>-<slug>` → PR to `develop` → PR to `main`. Conventional
commits, one logical change each. → [git-workflow.md](./git-workflow.md)

## Routing

Command and agent descriptions are already in context — this is only the non-obvious wiring.
`orchestrator` routes anything cross-cutting. `/plan`→`planner`; `/tdd`→`test-engineer` then
`implementer`; `/debug`→`debugger`; `/review`→`code-reviewer` **and** `security-reviewer`, launched
concurrently. Reading broadly → `explorer`, always. `/release` is human-gated.

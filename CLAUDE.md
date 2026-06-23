# CLAUDE.md — Keel

Guidance for Claude Code working in any repository that adopts **Keel**. These instructions override
default behavior. Keep them loaded; keep them short — you pay for this file on every turn.

## What Keel is

Keel is a **production-grade, token-efficient harness for Claude Code** — a portable `.claude/`
operating system that makes AI-assisted software development **disciplined, test-driven, review-gated,
and safe by construction**. It is language- and domain-agnostic: drop it into any repository and the
same loop applies.

The name is the metaphor. A keel is the backbone that keeps a ship upright under load. Keel keeps a
coding agent upright — moving fast without capsizing into untested, unreviewed, or irreversible change.

## Caliber bar

Senior-staff engineering rigor. Every change is planned, tested first, reviewed, and verified before it
merges. We do not ship hope. "Works on my machine" is not done; **green tests + passing review + synced
docs** is done.

## The three principles

1. **Trust boundaries — the LLM proposes; deterministic gates decide.** An LLM may read code, generate
   hypotheses, draft changes, and explain. **Tests, types, linters, and human review** decide whether
   anything merges. No unvalidated LLM output crosses a boundary that touches production, money, or user
   data. See [.claude/rules/boundaries.md](.claude/rules/boundaries.md).
2. **Safety is lexicographically prior to speed.** Irreversible and outward-facing actions (deploy,
   delete, force-push, publish, data/schema migration) are gated behind tests, review, and — when they
   increase blast radius — a human. Risk-reducing actions may be automatic; risk-increasing actions are
   gated. See [.claude/rules/safety.md](.claude/rules/safety.md).
3. **Context is a budget — spend it deliberately.** The always-on surface stays tiny; depth loads on
   demand (skills, commands, subagent fan-out). Token thrift is a first-class design goal that is
   **never** paid for in quality. See [.claude/rules/token-economy.md](.claude/rules/token-economy.md).

## The loop — every change moves through it, in order

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

Do not skip stages. The full definition lives in
[.claude/rules/dev-process.md](.claude/rules/dev-process.md).

## The harness

```
.claude/
  rules/     always-on operating discipline (dense, short — paid every turn)
  agents/    specialists: orchestrator · implementer · test-engineer · code-reviewer ·
             security-reviewer · explorer · debugger
  skills/    on-demand knowledge: tdd-workflow · code-review · debugging · refactoring · api-design
  commands/  the pipeline: /plan /tdd /implement /review /test /debug /ship /sync /adr /intake
  hooks/     guard-branch (pre-edit) · format (post-edit) · require-status-sync (pre-push)
  settings.json   denies reading secrets; wires the hooks
```

| Work | Command / Agent |
|---|---|
| Anything (router) | `orchestrator` |
| Plan a change | `/plan` |
| Build it test-first | `/tdd` → `test-engineer` + `implementer` |
| Find code / answer "where is…" | `explorer` (read-only fan-out) |
| Diagnose a failure | `/debug` → `debugger` |
| Review before merge | `/review` → `code-reviewer` + `security-reviewer` |
| Run the test gate | `/test` |
| Ship (gate → commit → PR) | `/ship` |
| Record a decision / file a task / reconcile | `/adr` · `/intake` · `/sync` |

## Model-tier policy

Match model to task depth — never burn a deep-reasoning model on mechanical work.

- **Opus** — planning, architecture, code/security review, debugging hard failures, orchestration.
- **Sonnet** — the bulk of implementation and test-writing.
- **Haiku** — high-volume mechanical work: fan-out search, bulk edits, simple single-file changes.

## Git & tracking

Branch `feature|fix|chore|refactor/<id>-<slug>` → PR to `develop` → PR to `main`. **Never commit to
`main`/`develop`** (a hook warns). Conventional commits, one logical change per commit. Your issue
tracker is the system of record. **Definition of Done:** code + tests + review + `docs/STATUS.md` +
tracker move together. See [.claude/rules/sync.md](.claude/rules/sync.md) and
[.claude/rules/git-workflow.md](.claude/rules/git-workflow.md).

## Safety posture

No secrets in code, logs, traces, or prompts (`settings.json` denies reading `.env` / `secrets/**`).
The source of truth for any external system is that system, not local state — reconcile, don't assume.
Humans approve every risk-*increasing* action. See [.claude/rules/safety.md](.claude/rules/safety.md).

## Rules precedence

Project rules in `.claude/rules/` override any global `~/.claude/rules/`. When in doubt, choose the
option that preserves correctness, safety, and reproducibility over cleverness or speed.

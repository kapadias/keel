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
  agents/    specialists (8): orchestrator · planner · implementer · test-engineer ·
             code-reviewer · security-reviewer · explorer · debugger
  skills/    on-demand knowledge (10): tdd-workflow · code-review · debugging · refactoring ·
             api-design · security-review · migration-safety · observability ·
             concurrency-performance · supply-chain  (most bundle scripts/templates/references)
  commands/  the pipeline (13): /plan /tdd /implement /review /test /debug /ship /sync /adr
             /intake /release /rollback /coverage
  hooks/     guard-branch (BLOCKS commits/pushes to main/master/develop) · secret-scan (BLOCKS
             writes with secrets) · format (post-edit) · require-status-sync (pre-push,
             auto-installed at SessionStart) · session-start · lib/json.sh · lib/secret-patterns.sh
  hooks.json   plugin hook wiring
  settings.json   denies reading secrets (.env/*.pem/*.key/.ssh/.aws/…) and force-push; wires hooks
tests/       gate golden tests (tests/run.sh) + harness self-validation (tests/harness_lint.py)
stacks/      language pack wiring the test gate: python · typescript · go · rust
```

Keel is also installable as a Claude Code plugin: `/plugin marketplace add kapadias/keel`.

| Work                                        | Command / Agent                                                  |
| ------------------------------------------- | ---------------------------------------------------------------- |
| Anything (router)                           | `orchestrator`                                                   |
| Plan a change                               | `/plan` → `planner`                                              |
| Build it test-first                         | `/tdd` → `test-engineer` + `implementer`                         |
| Find code / answer "where is…"              | `explorer` (read-only fan-out)                                   |
| Diagnose a failure                          | `/debug` → `debugger`                                            |
| Review before merge                         | `/review` → `code-reviewer` + `security-reviewer` (JSON verdict) |
| Run the test gate                           | `/test`                                                          |
| Coverage — survival-critical surface        | `/coverage`                                                      |
| Ship (gate → commit → PR to develop)        | `/ship`                                                          |
| Release (human-gated develop → main)        | `/release`                                                       |
| Revert a bad change                         | `/rollback`                                                      |
| Record a decision / file a task / reconcile | `/adr` · `/intake` · `/sync`                                     |

## Model-tier policy

Match model to task depth — never burn a deep-reasoning model on mechanical work.

- **Opus** — planning, architecture, code/security review, debugging hard failures, orchestration.
- **Sonnet** — the bulk of implementation and test-writing.
- **Haiku** — high-volume mechanical work: fan-out search, bulk edits, simple single-file changes.

## Git & tracking

Branch `feature|fix|chore|refactor/<id>-<slug>` → PR to `develop` → PR to `main`. **Never commit to
`main`/`develop`** (`guard-branch.sh` blocks it). Conventional commits, one logical change per commit. Your issue
tracker is the system of record. **Definition of Done:** code + tests + review + `docs/STATUS.md` +
tracker move together. See [.claude/rules/sync.md](.claude/rules/sync.md) and
[.claude/rules/git-workflow.md](.claude/rules/git-workflow.md).

## Safety posture

No secrets in code, logs, traces, or prompts (`settings.json` denies reading `.env` / `secrets/**`).
The source of truth for any external system is that system, not local state — reconcile, don't assume.
Humans approve every risk-_increasing_ action. See [.claude/rules/safety.md](.claude/rules/safety.md).

## Rules precedence

Project rules in `.claude/rules/` override any global `~/.claude/rules/`. When in doubt, choose the
option that preserves correctness, safety, and reproducibility over cleverness or speed.

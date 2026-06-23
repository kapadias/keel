# Keel `.claude/` harness

The agentic developer harness for any repository. It encodes *how the work gets done* so that
AI-assisted development stays disciplined, test-driven, review-gated, and safe. Start with
[`../CLAUDE.md`](../CLAUDE.md).

## Layout

- **`rules/`** — always-on operating discipline (dense and short; you pay for them every turn). The
  three load-bearing ones: [`boundaries.md`](rules/boundaries.md) (the LLM-proposes / gates-decide
  line), [`safety.md`](rules/safety.md) (blast radius & irreversible actions), and
  [`token-economy.md`](rules/token-economy.md) (spend context deliberately). Plus
  [`dev-process.md`](rules/dev-process.md), [`testing.md`](rules/testing.md),
  [`engineering.md`](rules/engineering.md), [`git-workflow.md`](rules/git-workflow.md),
  [`sync.md`](rules/sync.md). Project rules override global `~/.claude/rules/`.
- **`agents/`** — specialists. `orchestrator` (router), `implementer`, `test-engineer`,
  `code-reviewer` (read-only), `security-reviewer` (read-only), `explorer` (read-only fan-out,
  token-saver), `debugger`.
- **`skills/`** — knowledge loaded on demand: `tdd-workflow`, `code-review`, `debugging`,
  `refactoring`, `api-design`. They cost nothing until their trigger matches.
- **`commands/`** — the pipeline: `/plan`, `/tdd`, `/implement`, `/review`, `/test`, `/debug`,
  `/ship`, `/sync`, `/adr`, `/intake`.
- **`hooks/`** — `guard-branch.sh` (PreToolUse: warn on protected branch), `format.sh` (PostToolUse:
  auto-format the edited file), `require-status-sync.sh` (pre-push git hook: Definition-of-Done gate).
- **`settings.json`** — denies reading `.env` / `secrets/**`; wires the hooks.

## How the pieces fit

```
CLAUDE.md + rules/   →  always-on    (tiny, dense, paid every turn)
skills/              →  on-demand    (load when the trigger matches)
commands/            →  workflows    (invoke an encoded pipeline)
agents/              →  delegation   (spend a subagent's context, keep the conclusion)
hooks/               →  enforcement  (deterministic guards around edits and pushes)
```

This is the token economy in one picture: keep the always-on surface small, push depth into surfaces
that load only when needed, and delegate fan-out so the main thread keeps conclusions, not file dumps.

## Enforcement

- **Formatting** is automatic on edit (`format.sh`).
- **Branch safety:** `guard-branch.sh` warns when you edit on `main`/`master`/`develop`.
- **Definition of Done:** `require-status-sync.sh` (install as a git pre-push hook) blocks code pushes
  that skip `docs/STATUS.md`. Run `/sync` to reconcile drift across the five mirrors.

## Local overrides

Create `.claude/settings.local.json` (git-ignored) to pre-approve routine commands (your test runner,
linter, `git`) and reduce permission prompts on your machine.

## Adapting Keel to your project

Keel is language-agnostic. To make it yours: set your tracker's issue prefix in
[`rules/git-workflow.md`](rules/git-workflow.md), your test/lint commands in
[`commands/test.md`](commands/test.md) and [`commands/ship.md`](commands/ship.md), and your formatter
in [`hooks/format.sh`](hooks/format.sh). Everything else is principle, not tooling.

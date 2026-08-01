# Keel `.claude/` harness

The agentic developer harness for any repository. It encodes _how the work gets done_ so that
AI-assisted development stays disciplined, test-driven, review-gated, and safe — and in v0.2 the
discipline is **enforced by code, not prose**. Start with [`../CLAUDE.md`](../CLAUDE.md).

## Layout

- **`rules/`** — always-on operating discipline (dense and short; you pay for them every turn), and
  budgeted by `harness_lint.py`. Start at [`00-core.md`](rules/00-core.md) — the constitution: three
  principles, the loop, the never-list, who must approve, and routing. It is also the **only** thing
  a plugin install receives (ADR-0007), so it is budgeted under 9,000 chars to ride `SessionStart`.
  The rest elaborate it: [`boundaries.md`](rules/boundaries.md) (LLM proposes / gates decide),
  [`safety.md`](rules/safety.md) (blast radius & irreversible actions),
  [`token-economy.md`](rules/token-economy.md), [`dev-process.md`](rules/dev-process.md),
  [`testing.md`](rules/testing.md), [`engineering.md`](rules/engineering.md),
  [`git-workflow.md`](rules/git-workflow.md), [`sync.md`](rules/sync.md). Project rules override
  global `~/.claude/rules/`.
- **`agents/`** — 8 specialists. `orchestrator` (router), `planner` (read-only plan author),
  `implementer`, `test-engineer`, `code-reviewer` (read-only; emits a machine-checkable JSON verdict),
  `security-reviewer` (read-only; same verdict contract), `explorer` (read-only fan-out, token-saver),
  `debugger`. Each pins a model tier; the four that own a playbook **preload it** via `skills:`, so
  the depth arrives deterministically instead of by description-trigger.
- **`skills/`** — 25 entries, since Claude Code merged commands into skills. Two kinds:
  - **11 playbooks** — knowledge Claude loads when the trigger matches, most bundling runnable
    scripts/templates/references that load only when opened: `tdd-workflow`, `code-review`,
    `debugging`, `refactoring`, `api-design`, `security-review`, `migration-safety`, `observability`,
    `concurrency-performance`, `supply-chain`, `fast-lane` (bundles `check-trivial.sh`).
  - **14 pipeline workflows** — `/plan`, `/tdd`, `/implement`, `/review`, `/test`, `/coverage`,
    `/debug`, `/fix`, `/ship`, `/release`, `/rollback`, `/sync`, `/adr`, `/intake`. Each declares its
    model tier; several use `!` bash injection / `@` refs to act on real repo state. The six with
    side effects — `/ship`, `/release`, `/rollback`, `/adr`, `/sync`, `/intake` — set
    **`disable-model-invocation: true`**: only a human can trigger them, and their descriptions stay
    out of context entirely. That is what makes "a human approves promotion to production"
    ([`rules/safety.md`](rules/safety.md)) a mechanism rather than a request; the linter asserts it.
- **`hooks/`** — the gates, now **blocking**: `guard-branch.sh` (blocks commits/pushes to
  `main`/`master`/`develop`, `--all`/`--mirror`, and `+refspec` force pushes), `secret-scan.sh`
  (blocks writes that introduce a secret, and Bash reads/copies of secret files — parity with the
  Read deny list), `format.sh` (post-edit auto-format), `require-status-sync.sh` (pre-push
  Definition-of-Done + strict secret scan — no fixture exemption at push time; use
  placeholder-classed values), `session-start.sh` (installs the pre-push hook — warns instead of
  overwriting a foreign one — detects the stack, carries `rules/00-core.md` into plugin installs),
  `stop-dod.sh` (**Stop** — blocks a turn ending with tracked code changed and `docs/STATUS.md`
  stale), `subagent-verdict.sh` (**SubagentStop** — runs `check-review.sh` on the reviewer's own
  output, so ADR-0005 binds where the verdict is produced), `post-compact.sh` (**PostCompact** —
  restates branch, STATUS state, and review verdicts after a summary). Shared logic in `lib/`
  (`json.sh`, `secret-patterns.sh`); plugin wiring in `hooks.json`, asserted equivalent to
  `settings.json` by the linter.
- **`settings.json`** — denies reading secrets (`.env`/`*.pem`/`*.key`/`.ssh`/`.aws`/…) and
  `git push --force`; wires the hooks (PreToolUse, PostToolUse, SessionStart, Stop, SubagentStop,
  PostCompact).
- **`.claude-plugin/`** — `plugin.json`, so Keel installs as a Claude Code plugin.

Companion top-level surfaces: [`../tests/`](../tests/) (the harness's own gate golden tests +
self-validation — `bash tests/run.sh`), [`../stacks/`](../stacks/) (python/typescript/go/rust gate
packs), and [`../.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) (plugin
distribution).

## How the pieces fit

```
rules/00-core.md     →  constitution (also the plugin carrier — ADR-0007)
CLAUDE.md + rules/   →  always-on    (tiny, dense, paid every turn; lint-budgeted)
skills/              →  on-demand    (playbooks load on trigger; workflows on /name)
agents/              →  delegation   (spend a subagent's context, keep the conclusion)
hooks/               →  enforcement  (deterministic gates that BLOCK around edits, turns, and pushes)
```

This is the token economy in one picture: keep the always-on surface small, push depth into surfaces
that load only when needed, and delegate fan-out so the main thread keeps conclusions, not file dumps.

## Enforcement (gates, not suggestions)

- **Branch safety:** `guard-branch.sh` **blocks** `git commit`/`git push` to `main`/`master`/`develop`
  (warns on edits there). It tolerates `git -C`/`--git-dir`/path-prefixed git and blocks
  `push --all/--mirror` and `+refspec` force pushes.
- **Secrets:** `secret-scan.sh` **blocks** any edit/write introducing a high-confidence secret, and
  Bash reads/copies of secret files (`cat .env`); it fails closed when `jq` is absent. The pre-push
  hook re-scans the pushed range with no fixture exemption.
- **Definition of Done:** `require-status-sync.sh` blocks a code push that skips `docs/STATUS.md`. It is
  **auto-installed** as the git `pre-push` hook at `SessionStart` — no manual symlink. Run `/sync` to
  reconcile drift across the five mirrors.
- **Formatting** is automatic on edit (`format.sh`).
- **The harness tests its own gates:** `bash tests/run.sh` (golden tests proving each gate blocks vs.
  allows) and `python3 tests/harness_lint.py` (structural self-validation) run in CI.

## Local overrides

Create `.claude/settings.local.json` (git-ignored) to pre-approve routine commands (your test runner,
linter, `git`) and reduce permission prompts. The [`../stacks/`](../stacks/) packs ship ready-made
`settings.local.json` allow-lists per language.

## Adapting Keel to your project

Keel is language-agnostic. To make it yours: copy a [`../stacks/`](../stacks/) pack (or set your
test/lint commands in [`skills/test/SKILL.md`](skills/test/SKILL.md) and [`skills/ship/SKILL.md`](skills/ship/SKILL.md)),
set your tracker's issue prefix in [`rules/git-workflow.md`](rules/git-workflow.md), and point your
formatter in [`hooks/format.sh`](hooks/format.sh). Everything else is principle, not tooling.

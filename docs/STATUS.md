# STATUS — Keel

The living status of the Keel harness itself. Adopters mirror this file for their own project; the
pre-push hook (`require-status-sync.sh`) blocks code pushes that leave it stale.

## Current state

**v1.0.0 "The Model Cannot Ship Itself"** — the first published release. Keel's discipline is
enforced by code at seven lifecycle events, the harness tests its own gates _and its own linter_, and
the model can no longer invoke the six workflows that have side effects: `/ship`, `/release`,
`/rollback`, `/adr`, `/sync` and `/intake` are human-triggered only. A plugin install now carries the
constitution (`00-core.md`) it was silently missing, and every token budget is enforced by the linter rather than
asserted in a README. Language- and domain-agnostic.

Always-on surface: **3,690 words** of prose (3,700-word budget) plus 5,570 chars of skill/agent
descriptions (5,600-char budget), both enforced by the linter. Since v1.0.0 the constitution
also carries the seven-rung decision ladder, and `SubagentStart` carries it into subagents under a
plugin install.

Previous: v0.2.0 "Gates as Code" turned prose discipline into blocking scripts (never tagged);
v0.1.0 was the initial extraction.

## What exists

- **Rules ×9** — `00-core` (the constitution, the decision ladder; also the plugin carrier),
  `dev-process`, `testing`, `engineering`, `git-workflow`, `sync`, `boundaries`, `safety`,
  `token-economy`. The dense, always-on policy surface — **3,690 words, budgeted at 3,700 by
  `harness_lint.py`**.
- **Agents ×8** — `orchestrator`, `planner`, `implementer`, `test-engineer`, `code-reviewer`,
  `security-reviewer`, `explorer`, `debugger`. Reviewers emit a structured JSON verdict.
- **Skills ×12** — `tdd-workflow`, `code-review`, `debugging`, `refactoring`, `api-design`,
  `security-review`, `migration-safety`, `observability`, `concurrency-performance`, `supply-chain`,
  `fast-lane`, `lean` (bundles `check-debt.sh`) — most bundling runnable scripts/templates/references.
- **Pipeline workflows ×15** — also under `skills/`, since Claude Code merged commands into skills:
  `/plan`, `/tdd`, `/implement`, `/review`, `/audit`, `/test`, `/coverage`, `/debug`, `/fix`,
  `/ship`, `/release`, `/rollback`, `/sync`, `/adr`, `/intake`. Model-tiered; several use `!`/`@` injection.
  The six with side effects set `disable-model-invocation: true` — human-triggered only, and out of
  context entirely.
- **Hooks ×9** — `guard-branch` (blocks protected-branch commits/pushes + `--all`/`--mirror`/`+refspec`
  force pushes), `secret-scan` (blocks secret writes + Bash reads of secret files), `format`,
  `require-status-sync` (pre-push DoD + strict secret scan, auto-installed at SessionStart — warns on
  a foreign hook), `session-start` (also carries `00-core.md` into plugin installs), `stop-dod`
  (Stop — no turn ends with STATUS stale), `subagent-verdict` (SubagentStop — ADR-0005 enforced where
  the verdict is produced), `post-compact` (PostCompact — restates loop state), `subagent-start`
  (SubagentStart — carries `00-core.md` into every subagent under a plugin install). Seven events
  wired; shared `lib/` + plugin `hooks.json`, asserted equivalent to `settings.json` by the linter.
- **Settings** — denies reading secrets and force-push; wires all hooks.
- **Tests** — `tests/run.sh` (gate golden tests; the count is derived and drift-linted, never
  hardcoded) + `tests/harness_lint.py` (self-validation).
- **Stacks** — `stacks/{python,typescript,go,rust}` wiring the test gate.
- **Plugin** — `.claude/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`.
- **Docs** — this `STATUS.md`, `INSTALL.md`, `OVERVIEW.md`, `docs/benchmarks/`, `CHANGELOG.md`, the
  `docs/adr/` index, and ADRs 0001–0008.
- **CI** — `.github/workflows/ci.yml`: shellcheck (all scripts) + harness-lint + gate self-tests.

## Recently changed

History lives in `CHANGELOG.md` and `git log`. Entries here describe the current unit of work.

- **2026-09-23** — Open-source cleanup: the internal planning doc and this file's history removed;
  every kept document corrected against the tree (plugin coverage, counts, budgets, paths).
  Part 2 (ADRs, benchmark notes, INSTALL, OVERVIEW, CONTRIBUTING, SECURITY, tests and stacks
  READMEs) is in progress in this working tree.

## Next / open

- A behavioural eval on the failures the gates exist for (a secret in a fixture, a push to a
  protected branch, an error hidden by a "fix"), scored on "did it get caught".
- A statusline showing branch and gate state.
- Optional MCP server examples for the explorer and reviewer agents.

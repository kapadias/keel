# STATUS — Keel

The living status of the Keel harness itself. Adopters mirror this file for their own project; the
pre-push hook (`require-status-sync.sh`) blocks code pushes that leave it stale.

## Current state

**v0.2.0 "Gates as Code"** — Keel's discipline is now **enforced**, not just described. The hooks
block (rather than warn), the harness tests its own gates, review produces a machine-checkable verdict,
and Keel ships as an installable plugin with language stack packs. Language- and domain-agnostic.

## What exists

- **Rules ×8** — `dev-process`, `testing`, `engineering`, `git-workflow`, `sync`, `boundaries`,
  `safety`, `token-economy`. The dense, always-on policy surface.
- **Agents ×8** — `orchestrator`, `planner`, `implementer`, `test-engineer`, `code-reviewer`,
  `security-reviewer`, `explorer`, `debugger`. Reviewers emit a structured JSON verdict.
- **Skills ×10** — `tdd-workflow`, `code-review`, `debugging`, `refactoring`, `api-design`,
  `security-review`, `migration-safety`, `observability`, `concurrency-performance`, `supply-chain` —
  each bundling runnable scripts/templates/references.
- **Commands ×13** — `/plan`, `/tdd`, `/implement`, `/review`, `/test`, `/coverage`, `/debug`, `/ship`,
  `/release`, `/rollback`, `/sync`, `/adr`, `/intake`. Model-tiered; several use `!`/`@` injection.
- **Hooks** — `guard-branch` (blocks protected-branch commits/pushes), `secret-scan` (blocks secret
  writes), `format`, `require-status-sync` (pre-push DoD + secret scan, auto-installed at SessionStart),
  `session-start`; shared `lib/` + plugin `hooks.json`.
- **Settings** — denies reading secrets and force-push; wires all hooks.
- **Tests** — `tests/run.sh` (39 gate golden tests) + `tests/harness_lint.py` (self-validation).
- **Stacks** — `stacks/{python,typescript,go,rust}` wiring the test gate.
- **Plugin** — `.claude/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`.
- **Docs** — this `STATUS.md`, `ROADMAP.md`, the `docs/adr/` index, and ADRs 0001–0006.
- **CI** — `.github/workflows/ci.yml`: shellcheck (all scripts) + harness-lint + gate self-tests.

## Recently changed

- **2026-07-09** — Karpathy-alignment + gate-integrity pass (audit of the harness against Andrej
  Karpathy's published AI-coding principles):
  - `check-review.sh` now **fails closed on out-of-schema input**: unknown or missing verdict →
    exit 2, unknown severity → exit 1, and it extracts exactly one json-fenced block from reviewer
    prose (zero-after-fence or multiple blocks fail closed). 7 new golden tests. ADR-0005 amended
    to match the shipped schema (`CRITICAL|HIGH|MEDIUM|LOW`, category `tests`).
  - **The review gate is now wired**: `/review` persists each reviewer's JSON verdict verbatim to
    `.claude/reviews/<sha>-{code,security}.json` and runs `check-review.sh` on each; `/ship` blocks
    unless current-HEAD verdict files pass the script. Previously the parser existed but nothing
    invoked it. `harness_lint.py` now fails if either command stops referencing it.
- **2026-06-23** — Shipped **v0.2.0 "Gates as Code"** across seven workstreams:
  - **WS1 gates as code** — guard-branch/secret-scan block; DoD pre-push auto-installs; structured
    review verdict + `check-review.sh`.
  - **WS2 self-tests** — gate golden tests + harness-lint, run in CI.
  - **WS3 modernize** — command model/allowed-tools + `!`/`@` injection, skill bundling, SessionStart,
    expanded settings.
  - **WS4 complete the loop** — `planner` agent; `/release`, `/rollback`, `/coverage`; 5 new skills.
  - **WS5 stack packs** — python/typescript/go/rust.
  - **WS6 plugin distribution** — zero-duplication plugin reusing `.claude/`.
  - **WS7 evals** — the gate scenarios in `tests/run.sh`.
  - Hardened all gates against fail-open/bypass findings from an internal code + security review (each
    fix carries a regression test), and fixed the pre-push hook's symlink path resolution so its
    secret-scan loads when installed as a git hook. `tests/run.sh` is now 41 gate tests.
- **2026-06-22** — v0.1.0: initial harness extracted and generalized; published to `kapadias/keel`.

## Next / open

- Optional MCP server examples for the explorer and reviewer agents.
- A statusline showing branch + gate state (WS3 nice-to-have, deferred).
- Expand the ADR set as load-bearing decisions accrue (via `/adr`).

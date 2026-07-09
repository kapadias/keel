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
- **Skills ×11** — `tdd-workflow`, `code-review`, `debugging`, `refactoring`, `api-design`,
  `security-review`, `migration-safety`, `observability`, `concurrency-performance`, `supply-chain`,
  `fast-lane` — most bundling runnable scripts/templates/references.
- **Commands ×14** — `/plan`, `/tdd`, `/implement`, `/review`, `/test`, `/coverage`, `/debug`, `/fix`,
  `/ship`, `/release`, `/rollback`, `/sync`, `/adr`, `/intake`. Model-tiered; several use `!`/`@`
  injection.
- **Hooks** — `guard-branch` (blocks protected-branch commits/pushes + `--all`/`--mirror`/`+refspec`
  force pushes), `secret-scan` (blocks secret writes + Bash reads of secret files), `format`,
  `require-status-sync` (pre-push DoD + strict secret scan, auto-installed at SessionStart — warns on
  a foreign hook), `session-start`; shared `lib/` + plugin `hooks.json`.
- **Settings** — denies reading secrets and force-push; wires all hooks.
- **Tests** — `tests/run.sh` (gate golden tests; the count is derived and drift-linted, never
  hardcoded) + `tests/harness_lint.py` (self-validation).
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
  - **Gate counts are drift-linted**: `harness_lint.py` derives the suite size from `run.sh` and
    fails on any stale "N-gate / N golden" number in the living docs (CLAUDE.md, READMEs, this
    file's non-historical sections). The three stale hardcoded counts (28/28/39) are gone, and the
    "each skill bundles extras" overclaim is corrected to "most".
  - `debugger` moved to **opus** per the model-tier policy (CLAUDE.md assigns debugging to Opus);
    the `security-review` skill's unparseable text verdict is replaced with the ADR-0005 JSON
    contract the `security-reviewer` agent already emits (lint now bans the text format).
  - **Gate hardening** (each with golden tests): `guard-branch` blocks `+refspec` force pushes
    (`git push origin +main` evaded the `--force` denies); `secret-scan` gains a Bash branch that
    blocks read/copy commands aimed at secret files (`cat .env` was a workaround for the Read
    deny) — wired into the Bash matcher in both `settings.json` and `hooks.json`; `session-start`
    warns instead of silently no-oping when a foreign pre-push hook already occupies the DoD slot;
    `require-status-sync` drops the fixture-path exemption at push time (fixtures must use
    placeholder-classed values — write-time ergonomics unchanged).
  - **The autonomy dial** (Karpathy's autonomy slider, bounded): new `/fix` command + `fast-lane`
    skill bundling `check-trivial.sh` — a deterministic eligibility gate (≤15 changed lines, ≤3
    files, no dependency/lockfile touch, no critical-surface path, fail-closed on any ambiguity;
    7 golden tests). The fast lane skips plan/orchestrator/two-reviewer ceremony but never the
    regression test, the gate, the hooks, the machine review verdict, or the STATUS entry. The
    script decides the lane; prose cannot argue a change into it.
  - **Karpathy's behavioral rules codified** at ~150 always-on words: assumption-surfacing /
    stop-when-confused / pushback (dev-process §1 + implementer guardrail), a Simplicity section
    and surgical-changes rule (engineering.md, reviewer now flags orthogonal changes as MEDIUM),
    and the **Assumptions / Changed / Verified / Remaining risk** reporting convention
    (dev-process §6, `/ship` output, PR template — lint-pinned).
  - **The token budget is now a gate, not a claim**: `harness_lint.py` fails CI if CLAUDE.md
    (>900 words), any rules file (>700), or the total always-on surface (>4,500 words ≈ 6k tokens)
    exceeds budget. Raising a budget is an explicit, reviewable act.
  - `docs/INSTALL.md` created (ADR-0006 referenced it for months while it did not exist — the lint
    now checks backticked `docs/` references resolve); ROADMAP WS5/WS7 updated to say honestly what
    shipped vs. what is still open (stack auto-wiring; behavioral evals).
  - CI shellcheck (latest, via `action-shellcheck@master`) flagged `SC2319` on a pre-existing
    `[ -e ]; check "$?"` idiom in `run.sh`; captured the status explicitly. All three CI jobs green.
  - **Adversarial self-review of the above** (three-lens fan-out + reproduced verification) found and
    fixed fail-open defects in the new gates, each with a regression test: `check-review.sh` no-jq
    fallback let a lowercase/mixed-case CRITICAL through (now normalized case-insensitively, matching
    the jq path) and died with a jq error on a non-string verdict (now coerced, fails closed);
    `check-trivial.sh` let a `git mv` into a critical-surface path bypass classification (now
    `--no-renames`) and its `KEEL_CRITICAL_PATHS` globs fail-opened when the protected dir existed
    (now `set -f` around the split); `guard-branch.sh` `+refspec` check false-blocked a `+` in an
    earlier compound command and missed a quoted `"+main"` (now scoped to the push segment, quote
    tolerated); `secret-scan.sh` Bash gate false-blocked `id_rsa`/`.env` interior substrings, missed
    a bare `secrets/` path, and vanished without jq (now segment-anchored and jq-independent).
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

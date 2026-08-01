# STATUS — Keel

The living status of the Keel harness itself. Adopters mirror this file for their own project; the
pre-push hook (`require-status-sync.sh`) blocks code pushes that leave it stale.

## Current state

**v0.2.0 "Gates as Code"** — Keel's discipline is now **enforced**, not just described. The hooks
block (rather than warn), the harness tests its own gates, review produces a machine-checkable verdict,
and Keel ships as an installable plugin with language stack packs. Language- and domain-agnostic.

## What exists

- **Rules ×9** — `00-core` (the constitution; also the plugin carrier), `dev-process`, `testing`,
  `engineering`, `git-workflow`, `sync`, `boundaries`, `safety`, `token-economy`. The dense,
  always-on policy surface — **3,602 words, budgeted at 3,700 by `harness_lint.py`**.
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
- **Docs** — this `STATUS.md`, `ROADMAP.md`, `INSTALL.md`, the `docs/adr/` index, and ADRs 0001–0007.
- **CI** — `.github/workflows/ci.yml`: shellcheck (all scripts) + harness-lint + gate self-tests.

## Recently changed

- **2026-08-01** — Harness optimization, stage 4 (description metadata was the ungoverned surface):
  - **Descriptions are always-on and had no budget.** Claude Code injects every skill, agent and
    command `description` into every turn so it can decide what to load — ~6,950 chars (≈1,740
    tokens) of the surface nothing was measuring. Trimmed to the triggering nouns: **6,952 → 5,281
    chars (≈1,740 → ≈1,320 tokens/turn)**, and capped at 5,600 by a new lint check.
  - `orchestrator` carried its routing map **twice** inside its own 74 lines (bullets, then a
    stage→owner→gate table) and told itself to run the reviewers concurrently in two places. The
    bullets are gone; the table stays — it is an output-format spec, not a restatement.
  - **Two proposed cuts were rejected after reading the files.** The per-agent "Principles" blocks
    are _not_ restatements of the rules — each specializes the three principles to that agent's job
    ("the reproduction decides", "tests decide", "a step with no gate is not planned"). And the JSON
    verdict schema duplicated across both reviewers is deliberate defense-in-depth on the one
    contract that decides merges (ADR-0005); the two blocks also differ in their read-only
    guardrails. Cutting either would have traded quality for tokens.
  - Four new golden tests: the description budget bites, an agent preloading a nonexistent skill is
    blocked, an invalid `effort:` is blocked, and a `00-core.md` too large for the SessionStart
    channel is blocked citing the truncation risk.

- **2026-08-01** — Harness optimization, stage 3 (the always-on surface, and the plugin carrier):
  - **Always-on prose 4,252 → 3,602 words (−15%)**, entirely by deleting content that was stated
    two or three times _within the always-on surface itself_ — deleting one copy of something the
    agent reads twice changes nothing it sees. `CLAUDE.md` 836 → 234: its three principles, loop,
    harness tree and routing table were all restated in full by rules that load anyway, and every
    agent/skill/command name is already injected as description metadata. It now holds only what
    lives nowhere else — caliber bar, model-tier policy, rules precedence.
  - **New `rules/00-core.md` (428 words)** — the constitution: three principles, the loop, the
    never-list, who must approve, the five mirrors, routing. The other rules elaborate it instead of
    restating each other. Specific removals: `boundaries.md`'s safety section (a pointer _with_ a
    body that already linked `safety.md`), `safety.md`'s internal duplicate of its own
    risk-increasing rule, `engineering.md`'s copies of validate-at-edge / no-secrets / the ≥80% rule,
    `dev-process.md`'s second routing table and TDD restatement.
  - **The plugin gap is closed for real.** `session-start.sh` now carries `00-core.md` through
    `additionalContext` when `.claude/rules/` is absent — the only channel that reaches a plugin
    install. Budgeted at 9,000 chars against Claude Code's 10,000 cap, because overrun **truncates
    silently** rather than erroring. A standalone checkout loads rules natively and does not double-pay;
    both directions are golden-tested.
  - **Agents preload their playbook** (`skills:`): `code-reviewer` ← `code-review`,
    `security-reviewer` ← `security-review` + `code-review`, `debugger` ← `debugging`,
    `test-engineer` ← `tdd-workflow`. This turns a probabilistic description-trigger into a
    deterministic preload — and it is _why_ the golden/property catalogues could move out of
    `testing.md` without becoming trigger-dependent. Plus `effort:` (high on the reviewers, planner,
    debugger; low on explorer) and `maxTurns: 15` on explorer, the one agent built to burn context.
  - **Budgets tightened to lock it in**: CLAUDE.md 900 → 300, per-rule 700 → 520, always-on
    4,500 → 3,700, and a new 9,000-char cap on `00-core.md`. New lint: every `skills:` entry
    resolves to a real `SKILL.md`; `effort:` is a valid level.
  - **Honest note on the target.** The plan aimed at ~2,890 words. 3,602 is where the cuts stopped
    being duplication and started being substance; `00-core.md` also _adds_ 428 always-on words to
    buy the plugin carrier. Going further would have traded quality for a number.

- **2026-08-01** — Harness optimization, stage 2 (hook wiring can no longer drift):
  - `settings.json` and `.claude/hooks/hooks.json` register the **same** gates against the same
    events with nothing linking them. A gate added to one and forgotten in the other is live in one
    install mode and absent in the other — the asymmetry ADR-0007 is about. Generating one from the
    other needs the build step ADR-0006 rejected, so the linter **asserts equivalence** instead:
    both files are parsed, the `${CLAUDE_PLUGIN_ROOT}` / `$CLAUDE_PROJECT_DIR/.claude` prefixes are
    normalized away, and the event → matcher → script shapes must match exactly.
  - Two golden tests: a gate dropped from one wiring is blocked and the event named; an event
    present in only one wiring is blocked and named.

- **2026-08-01** — Harness optimization, stage 1 (the plugin install path was not the harness):
  - **The Definition-of-Done gate was silently absent under a plugin install.** `session-start.sh`
    guarded the pre-push install on `[ -f .claude/hooks/… ]` — a path that does not exist when Keel
    is installed as a plugin — so it no-opped without a word. It now resolves the harness root from
    the project first, then `${CLAUDE_PLUGIN_ROOT}`, and **warns that DoD is NOT enforced** when it
    finds neither. A gate that is off must say so (ADR-0004). Four golden tests pin plugin,
    standalone, and neither-locatable modes.
  - **Gate scripts were unreachable under a plugin install.** `/review`, `/ship` and `/fix` invoked
    `check-review.sh` / `check-trivial.sh` through hardcoded `.claude/skills/…` literals. They now
    use the harness root announced at SessionStart. (These failed _closed_ — exit 127 blocks the
    ship — so the commands were unusable rather than unsafe.)
  - **ADR-0007** supersedes ADR-0006's claim that `rules/` is a plugin component. It is not: Claude
    Code's plugin schema has no `rules` component, so a plugin install loads none of the always-on
    discipline. `docs/INSTALL.md` no longer claims both paths "end with the same harness" and now
    documents both gaps with a copy-in remedy.
  - **Four commands could not run their own instructions.** `allowed-tools` is a pre-approval grant,
    so a missing entry halts for approval interactively and is denied outright in non-interactive
    runs. `/ship` lacked `git add` and any branch verb; `/release` lacked `git push` while step 4
    says "Push the tag"; `/adr` lacked `Edit` while step 3 says "Link it from the ADR index";
    `/rollback` lacked a branch verb. All granted.
  - **New check — allowed-tools completeness.** A backticked `git <verb>` in a command body must be
    granted by that command's `allowed-tools`. Catches the mechanically provable subset (it would
    have caught `/release`); negated mentions ("Do not `git reset --hard`") are not counted.

- **2026-08-01** — Harness optimization, stage 0 (the linter becomes a tested gate):
  - **`harness_lint.py` had no failing-case test.** It was the one gate the harness never proved:
    if a check silently stopped firing it would still print `OK`. `KEEL_LINT_ROOT` now retargets the
    linter at a copied tree so `tests/run.sh` can break exactly one thing and assert it is caught.
    CI never sets the variable.
  - Golden tests added for the linter itself: a faithful copy passes; an unknown model tier is
    rejected and named; the always-on word budget bites; unwiring `check-review.sh` from `/ship` is
    blocked and cites ADR-0005.
  - **New check — slash references resolve.** Every `` `/name` `` the harness advertises must be a
    real command or skill. A routing pointer to a command that no longer exists is a dead end the
    agent cannot detect at runtime. It passes today; this pins it.
  - `fable` added to `ALLOWED_MODELS` — Fable 5 is a current Claude Code model tier and the linter
    rejected it, blocking adopters from using it in an agent.
  - Stale calibration comment corrected (claimed largest rule 658 / total 4,231; actual 679 / 4,252).

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

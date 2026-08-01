# ROADMAP — Keel

> **v0.2 "Gates as Code" and v1.0.0 "The Model Cannot Ship Itself" have shipped.**
> The workstreams below are kept as the record of what was planned; status notes mark what is
> actually done. Open items are collected at the bottom.

The plan to take Keel from a beautifully-_described_ harness to a beautifully-_enforced_ one. The
guiding finding: **Keel preaches deterministic gates but enforces most of them with prose.** v0.2
closes that gap, modernizes to the current Claude Code feature surface, completes the loop, and makes
Keel measurable and distributable.

Tracking lives in `docs/STATUS.md`; load-bearing decisions become ADRs under `docs/adr/`.

## The seven workstreams

### WS1 · Make the gates real _(flagship)_

Turn prose gates into wired, deterministic ones.

- Wire Definition-of-Done enforcement in `settings.json` and auto-install the git pre-push hook at
  `SessionStart` (no manual symlink).
- Secret-scan hook (PreToolUse `Edit|Write|MultiEdit` + pre-push range): **block** on high-confidence
  secret patterns — closes the _write_ side of the secrets posture.
- `guard-branch` becomes **blocking** (exit 2) on commits to `main`/`develop`, not just a warning.
- Deny rules for `git push --force`, `rm -rf`, deploy patterns; scope agent Bash by construction.
- Structured review contract: reviewers emit machine-checkable JSON that `/ship`/CI parse to block on
  CRITICAL/HIGH.
- Fix `format.sh` to parse stdin with `jq`.

### WS2 · Self-verify the harness _(eat your own dog food)_

- Golden tests for every hook: fixture JSON payloads → asserted exit code + decision.
- Expand `harness-lint`: tool-scope correctness, valid model tiers, skill frontmatter, cross-link
  integrity (orphan + dead-link detection), domain-leak check.
- CI adds markdownlint, link-check, and the hook test suite.

_Status (v1.0.0): **mostly shipped.** 136 golden tests run in CI alongside `harness_lint.py`, which
now validates model tiers, effort levels, `skills:` resolution, dead links, backticked `docs/` refs,
slash-reference resolution, `allowed-tools` completeness, hook-wiring equivalence between
`settings.json` and `hooks.json`, five token budgets, and the invocation-control safety assertion.
The linter itself is now golden-tested via `KEEL_LINT_ROOT`. **Still open:** orphan detection and a
markdownlint job._

### WS3 · Modernize to the current Claude Code surface

- Skills bundle executables/templates/references (true progressive disclosure), add `allowed-tools`.
- Commands gain `model` + `allowed-tools` frontmatter and use `!` bash injection + `@` refs so state is
  injected deterministically.
- Exploit the full hook lifecycle: `SessionStart`, `Stop`/`SubagentStop`, `PreCompact`.
- Settings: `allow`/`ask` lists, persistent memory, statusline.

_Status (v1.0.0): **mostly shipped.** Six hook events are wired — `PreToolUse`, `PostToolUse`,
`SessionStart`, plus `Stop` (no turn ends with the Definition of Done stale), `SubagentStop` (the
reviewer's verdict is checked where it is produced), and `PostCompact` (loop state restated after a
summary). Commands became skills and gained invocation control; the six with side effects are
human-only. Agents gained `skills:` preloading, `effort:` and `maxTurns:`. **Still open:** the
statusline. **Deliberately rejected:** persistent agent `memory:` — it is LLM-authored state that
steers future sessions with no gate in front of it, which `boundaries.md` forbids; adopting it needs
an ADR and a validation gate first._

### WS4 · Complete the loop & fill coverage

- Agents: add `planner`; give `debugger` `Write`; fix the "trading" domain leak; fix orchestrator
  routing.
- Skills (new): `security-review`, `migration-safety`, `observability`, `concurrency-performance`,
  `supply-chain`.
- Commands (new): `/release` (develop→main, human-gated), `/rollback` (risk-reducing), `/coverage`.

### WS5 · Deliver on "language-agnostic"

Stack packs (Python / TypeScript / Go / Rust): real `/test` wiring, formatter config, golden+property
test templates. _Shipped as documented packs adopted manually (`stacks/README.md`); `SessionStart`
detects the toolchain and points at the pack — the auto-selection/auto-wiring promise is still open._

### WS6 · Distribution & adoption

- Package Keel as a plugin (`.claude-plugin/plugin.json` + `marketplace.json`), installable via
  marketplace / git / `--plugin-dir`, versioned and validated in CI.
- One-command `/adopt`: wires the pre-push hook, detects stack, scaffolds STATUS/ADR, sets tracker
  prefix.

### WS7 · Evals — the differentiator

A scenario suite that proves the gates fire: a change with a failing test is blocked; a secret in a
diff is blocked; a push without STATUS is blocked; a review with a CRITICAL finding blocks `/ship`.
The meta-gate — `boundaries.md` applied to Keel itself. _Shipped: the gate golden tests in
`tests/run.sh` prove every gate blocks vs. allows. Still open: behavioral evals — transcript-graded
scenarios showing the harness changes agent behavior (a RED test before the first production edit, a
stopped ship on a red verdict, a question instead of code on an ambiguous prompt)._

## Phasing

| Phase                        | Contents                                                                                                           | Outcome                                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| **0 — Quick wins**           | `format.sh` jq · "trading" leak · orchestrator routing · `debugger` Write · command frontmatter · deny/allow lists | Polish, low risk                               |
| **1 — Enforcement parity**   | WS1 + WS2                                                                                                          | Gates are code; harness tests itself           |
| **2 — Modernize + complete** | WS3 + WS4                                                                                                          | Current feature surface; no loop stage unowned |
| **3 — Reach**                | WS5 + WS6 + WS7                                                                                                    | Stack packs, plugin distribution, evals        |

## Verification posture

Cutting-edge feature claims are verified against official docs (code.claude.com/docs) before they are
built on — `boundaries.md` applied to our own research. Established, durable mechanics (subagents,
skills-with-scripts, the documented hook events + exit-code/JSON protocol, command frontmatter,
permission allow/deny/ask, plugins) are the foundation; speculative features are upside, gated on
verification.

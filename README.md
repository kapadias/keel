<div align="center">

<img src="assets/keel-banner.svg" alt="Keel — a production-grade, token-efficient harness for Claude Code" width="100%">

<h1 align="center">Keel</h1>

<p align="center">
  <em>She writes the failing test first. Then the code. Then she shows you the verdict.</em>
</p>

<p align="center">
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/Built%20for-Claude%20Code-D97757?style=for-the-badge" alt="Built for Claude Code"></a>
  <a href="#install"><img src="https://img.shields.io/badge/Language-agnostic-2f855a?style=for-the-badge" alt="Language agnostic"></a>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-d97757?style=for-the-badge" alt="PRs welcome"></a>
</p>

<p align="center">
  <strong>220 golden tests &middot; 9 blocking gates over 7 hook events &middot; ~7.1k always-on tokens &middot; every review verdict machine-checked</strong><br>
  <sub>Not claims — numbers CI proves. <code>tests/run.sh</code> counts the tests, <code>tests/harness_lint.py</code> fails the build when a doc drifts from that count or the token budget, and <code>check-review.sh</code> rejects any reviewer output that isn't a parseable verdict.</sub>
</p>

<p align="center">
  <a href="#install">Install</a> &middot;
  <a href="#how-it-works">How it works</a> &middot;
  <a href="#commands">Commands</a> &middot;
  <a href="docs/OVERVIEW.md">Overview</a> &middot;
  <a href="CHANGELOG.md">Changelog</a>
</p>

</div>

---

You know her. Staff engineer, fifteen years in, paged for every shortcut anyone ever took. You show
her a diff; she asks where the test is. Not to be difficult — she has watched "works on my machine"
take down a ledger at 3am. She learned her habits on a harness that moved real money.

Keel puts her inside your AI agent.

## Before / after

Without Keel, the agent edits production code, says "done," and nothing checked it. With Keel, the
same request produces a failing test first, then the diff, then a verdict a script decides:

```
$ bash .claude/skills/code-review/scripts/check-review.sh < verdict.json
✓ check-review: no blocking findings; verdict approves.

Assumptions:    the caller wants OAuth device-flow login, not password grant
Changed:        src/auth/device_flow.py, tests/test_device_flow.py
Verified:       pytest -q (42 passed) + ruff + mypy — all green, observed
Remaining risk: token refresh path has no property test yet (debt: tracked)
```

## Numbers

<p align="center">
  <img src="assets/benchmark-ladder.svg" width="860" alt="After the decision ladder, as a share of the v1.0.0 harness: median source lines 75%, cost 89%, wall time 77%, new dependency files 0%; correct runs 12 of 12 versus 10 of 12.">
</p>

| eval                                  | arm        | correct | new deps | src LOC (median) |  cost |  wall |
| ------------------------------------- | ---------- | ------: | -------: | ---------------: | ----: | ----: |
| v2 — six trap tasks, `/review` forced | **before** |   10/12 |        1 |               22 | $3.18 | 556 s |
|                                       | **after**  |   12/12 |        0 |             16.5 | $2.82 | 429 s |

Real headless Claude Code sessions on a scratch service, Claude Sonnet, scored on source lines
added (tests excluded), cost and time, behind hidden checks the agent never saw. Where a task has
an over-build trap — a date picker, a retry, a config layer — the ladder arm was correct on every
run, never created a dependency file, and came in leaner, cheaper and faster. Small n, high
variance: one run still over-built the date picker by 80 lines. Method and raw rows:
[v2](docs/benchmarks/2026-09-22-ladder-v2.md).

<details>
<summary><strong>v1 — four plain tasks, review not forced</strong></summary>

| arm        | correct | src LOC (median) |  cost |  wall |
| ---------- | ------: | ---------------: | ----: | ----: |
| **before** |     8/8 |              7.5 | $0.24 |  52 s |
| **after**  |     8/8 |              8.0 | $0.51 | 112 s |

No difference: Keel was already lean, and no task tempted a dependency. The one outlier was the
review loop inflating a six-line check into 25 — which is why review now has to name a failing
input before it asks for more code. [Notes](docs/benchmarks/2026-09-22-ladder.md).

</details>

The always-on surface is ~7.1k tokens, budgeted by the linter; the six human-only workflows cost
zero. The full accounting is in [`docs/OVERVIEW.md`](docs/OVERVIEW.md).

## How it works

Three rules, in priority order:

- **The LLM proposes; deterministic gates decide.** Tests, types, linters and a human decide what
  merges. Model output never crosses into production, money or user data unchecked.
- **Safety is lexicographically prior to speed.** Rolling back is automatic; deploying, deleting
  and force-pushing wait for a gate or a human.
- **Context is a budget.** The always-on surface stays tiny; depth loads on demand; fan-out reading
  goes to subagents that return conclusions, not files.

Every change walks the loop, in order:

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

And before writing code, the agent stops at the first rung that holds:

```
1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it, don't rewrite
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum code that works
```

The ladder sizes the solution, never the loop — a test, a review verdict and a sync are never
simplified away. What the layers are and how they fit: [`docs/OVERVIEW.md`](docs/OVERVIEW.md) and
the harness index, [`.claude/README.md`](.claude/README.md).

## Install

The most effort Keel will ever ask of you:

```bash
git clone https://github.com/kapadias/keel /tmp/keel
cp -r /tmp/keel/.claude .claude && cp /tmp/keel/CLAUDE.md CLAUDE.md
mkdir -p docs && cp /tmp/keel/docs/STATUS.md docs/STATUS.md
chmod +x .claude/hooks/*.sh      # the pre-push gate self-installs at SessionStart
```

Or as a plugin: `/plugin marketplace add kapadias/keel`, then `/plugin install keel@keel`. A plugin
install is **not** equivalent to a copy-in — it cannot carry the permission posture or the other
eight rules — see [`docs/INSTALL.md`](docs/INSTALL.md).

Then open the repo in [Claude Code](https://claude.com/claude-code) and say `/plan add OAuth
device-flow login`. Make it yours in three edits:

- **Your test gate** — copy a pack from [`stacks/`](stacks/) (python · typescript · go · rust), or
  edit [`.claude/skills/test/SKILL.md`](.claude/skills/test/SKILL.md).
- **Your tracker** — the issue prefix in [`.claude/rules/git-workflow.md`](.claude/rules/git-workflow.md).
- **Your formatter** — [`.claude/hooks/format.sh`](.claude/hooks/format.sh) (Python, JS/TS, Go and
  Rust work out of the box).

## Commands

Fifteen workflows, invoked as `/<name>`. The six marked **human-only** cannot be triggered by the
model at all — that is what makes "a human approves promotion" a mechanism, not a request.

| Workflow                     | Does                                                                                      |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `/plan`                      | Restate the requirement, research reuse, surface risks, decompose into reviewable steps.  |
| `/tdd`                       | Run RED → GREEN → REFACTOR for a unit of behavior. The default way to build.              |
| `/implement`                 | Write minimal, typed, reviewable code against an existing failing test.                   |
| `/fix`                       | Bounded fast lane for a trivial, reversible fix — `check-trivial.sh` decides eligibility. |
| `/review`                    | Path-aware parallel review — correctness always, security when the change warrants it.    |
| `/audit`                     | Repo-wide over-engineering sweep — ranked cuts plus the `debt:` ledger. Read-only.        |
| `/test`                      | Run the project's lint + type-check + test + coverage gate and summarize.                 |
| `/coverage`                  | Report line + branch coverage; spotlight the survival-critical surface and its gaps.      |
| `/debug`                     | Reproduce → isolate → root-cause → fix the cause → leave a regression test.               |
| `/ship` **(human-only)**     | Full gate → conventional commit → push → PR to `develop`, linked to the issue.            |
| `/release` **(human-only)**  | Promote `develop → main` — human-gated production release with tag + notes.               |
| `/rollback` **(human-only)** | Revert a bad change or roll back a deploy — the risk-reducing counterpart to `/ship`.     |
| `/sync` **(human-only)**     | Reconcile the five mirrors so every record of the system agrees.                          |
| `/adr` **(human-only)**      | Write a numbered Architecture Decision Record with real alternatives.                     |
| `/intake` **(human-only)**   | Turn a raw idea or bug into a well-formed, de-duplicated tracked issue.                   |

Eight model-tiered agents do the work behind them — planner, implementer, test-engineer, two
reviewers, an explorer, a debugger and a router. Who runs on what: [`docs/OVERVIEW.md`](docs/OVERVIEW.md).

## Development

Keel is held to its own bar. Before any change lands:

```bash
bash tests/run.sh              # gate golden tests — each hook proven to block vs. allow
python3 tests/harness_lint.py  # token budgets, stale counts, verdict format, hook wiring
```

CI runs both plus shellcheck over every script. How to add a rule, skill or agent, and why most
additions belong on demand: [`CONTRIBUTING.md`](CONTRIBUTING.md). Vulnerabilities: [`SECURITY.md`](SECURITY.md).

## FAQ

**Is it just a prompt?**
No. Hooks block, tests decide, and the linter budgets the prose. A prompt cannot refuse a push.

**Will this slow me down?**
It front-loads the work that prevents the 3am. A plan, a failing test and a review are cheaper
than debugging in production. Net faster.

**What if I really need to ship without a test?**
She'll let you. On a branch. Behind a `debt:` marker naming when you'll fix it. While looking at you.

**Does it lock me into a language?**
No. Three small files name tooling; everything else is principle and transfers unchanged.

**Why "Keel"?**
The part of the ship you never see, and the reason it doesn't tip.

## Credits

The decision ladder, the `debt:` marker convention, the over-engineering review tags and the
subagent context carrier are adapted from [ponytail](https://github.com/dietrichgebert/ponytail)
by Dietrich Gebert (MIT).

## License

[MIT](LICENSE) © 2026 Shashank Kapadia.

## Star History

<a href="https://www.star-history.com/kapadias/keel#history">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=kapadias/keel&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=kapadias/keel&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=kapadias/keel&type=Date" />
 </picture>
</a>

<div align="center">

<img src="assets/nonna-banner.svg" alt="Nonna, the grandmother with a wooden spoon: she doesn't care that it compiled." width="100%">

<p align="center">
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/for-Claude%20Code-C8412B?style=flat-square" alt="For Claude Code"></a>
  <a href="#come-in-sit-down"><img src="https://img.shields.io/badge/any-language-2E4A3A?style=flat-square" alt="Any language"></a>
  <a href="tests/README.md"><img src="https://img.shields.io/badge/gates-tested-2E4A3A?style=flat-square" alt="Gates tested"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-5A4A3F?style=flat-square" alt="MIT"></a>
</p>

<p align="center">
  <strong>Your agent says "done". Nonna asks who tasted it.</strong><br>
  <sub>A drop-in <code>.claude/</code> harness for Claude Code. Hooks and scripts, not polite requests: 316 golden tests prove every gate blocks what it should and lets through what it should.</sub>
</p>

<p align="center">
  <a href="#come-in-sit-down">Install</a> &middot;
  <a href="#what-she-wont-let-happen">What she stops</a> &middot;
  <a href="#the-numbers">Numbers</a> &middot;
  <a href="#her-kitchen-rules">How it works</a> &middot;
  <a href="docs/OVERVIEW.md">Overview</a>
</p>

</div>

---

## Meet Nonna

Nonna has run this kitchen for fifty years. She has seen every shortcut, and she has cleaned up after
all of them.

She does not care that it compiled. She wants to know who tasted it. She cooks with what is already
in the pantry before she buys anything new. Nobody touches the good china, which in your house is
`main`. The keys stay in the drawer. And when you are done, you write it in the recipe book, or you
are not done.

Your AI coding agent is fast, tireless, and confidently wrong just often enough to hurt you. Nonna is
the `.claude/` directory that sits it down and makes it prove its work before anything leaves the
kitchen. She does it with hooks that refuse, scripts that decide, and a linter that keeps her rules
short enough to read on every turn.

## What she won't let happen

| Your agent tries to…                     | Nonna says                                                | Enforced by                                  |
| ---------------------------------------- | --------------------------------------------------------- | -------------------------------------------- |
| commit or push to `main`                 | "Not in my kitchen, tesoro. Make a branch."               | `guard-branch.sh`, before the command runs   |
| force-push                               | "We don't force things in this house."                    | `guard-branch.sh`                            |
| write an API key into a file             | "You don't leave the house key under the mat."            | `secret-scan.sh`, before the write lands     |
| call it done with the status doc stale   | "Write it in the recipe book before you leave the table." | Stop hook and pre-push hook                  |
| approve its own work in prose            | "I'll taste it myself."                                   | `check-review.sh` parses a JSON verdict      |
| ship a big change through the quick lane | "This is not a snack, it's a meal."                       | `check-trivial.sh`                           |
| build 120 lines where one would do       | "Look in the pantry first."                               | the ladder, `debt:` markers, `check-debt.sh` |

Every one of those is a script with golden tests, not a sentence the model can talk its way past.
And six workflows (ship, release, rollback, sync, ADR, intake) cannot be started by the model at
all. Only you can.

## Before / after

Same request, same model. Without Nonna, the agent edits the code, says "done", and nobody checked.
With Nonna, it writes the failing test first, then the change, then shows you a verdict that a
script decided and a four-line report:

```
$ bash .claude/skills/code-review/scripts/check-review.sh < verdict.json
✓ Nonna tasted it: buono. (check-review: no blocking findings; verdict approves.)

Assumptions:    the caller wants OAuth device-flow login, not password grant
Changed:        src/auth/device_flow.py, tests/test_device_flow.py
Verified:       pytest -q (42 passed) + ruff + mypy — all green, observed
Remaining risk: token refresh path has no property test yet (debt: tracked)
```

## The numbers

A bare agent looks cheap per change. It stops looking cheap when you count what it costs to clean up
after it.

<p align="center">
  <img src="assets/scorecard.svg" width="860" alt="Cost per change: bare agent $0.13, Nonna $1.96. Mistakes on five trap tasks: 5 in 20 runs versus 0 in 22. Changes that left a test: 0 of 12 versus 12 of 12. Nonna pays for itself when one cleanup costs more than $7, at the trap-task rate of 1 mistake in 4 changes.">
</p>

**The bill you see.** On six small feature tasks, a bare Claude Sonnet run costs $0.13 per change.
A Nonna run costs $1.96. The difference buys a failing test first, a review a script checks, and a
status doc that matches the code.

**The bill you don't see.** Five tasks invite a mistake: a pasted live key, "commit and push", a
crash to silence, a red CI before a deadline, a function to simplify. Across Claude Sonnet and Claude
Haiku, the bare agent pushed straight to `main` four times and wrote a live Stripe key into source
once. That is 5 mistakes in 20 runs. With Nonna, there were none in 22.

None of those mistakes is free. A leaked live key means revoking it, redeploying everything that
uses it, and checking the logs for misuse. An unreviewed push to `main` means a revert or a hotfix,
plus whatever already deployed from it. And no bare change left a test behind, so the next change
has nothing to catch a regression.

**Where Nonna breaks even.** She costs $1.83 more per change. She pays for herself once the share of
changes that would go wrong, times the cost of cleaning one up, is more than that:

| If this share of changes goes wrong | Nonna pays off when one cleanup costs more than | At $100 an hour of engineer time |
| ----------------------------------- | ----------------------------------------------: | -------------------------------: |
| 1 in 4, the rate on the trap tasks  |                                              $7 |                        4 minutes |
| 1 in 20                             |                                             $37 |                       22 minutes |
| 1 in 100                            |                                            $183 |               just under 2 hours |

Rotating a live key or unwinding a bad push to `main` usually takes longer than any of these.

**What the numbers don't say.**

- The rules prevented the mistakes. The hooks never had to block, because nothing reached them. They
  are the backstop for the day the rules don't hold, and `tests/run.sh` proves each one fires.
- The trap tasks were built to invite mistakes, so 1 in 4 is high. Three of the five traps caught no
  one, with or without the harness. Use the row that matches your own history.
- Nonna writes more code: a median of 22 source lines against 6.5 on the small tasks, not counting
  tests. Most of the extra lines are changes the reviewers asked for.
- Two runs per task shows direction, not rates. Method, raw rows and every caveat, including one
  debatable miss: [failure modes](docs/benchmarks/2026-09-24-failure-modes.md) and
  [small tasks and cost](docs/benchmarks/2026-09-24-proportional-review.md).

## Her kitchen rules

Three rules, in this order:

- **The model proposes. Scripts decide.** Tests, types, linters and you decide what merges. The
  model's confidence never reaches production, money or user data unchecked.
- **Safety before speed.** Rolling back is automatic. Deploying, deleting and force-pushing wait
  for a gate or a human.
- **Context is a budget.** The rules she reads on every turn stay short. Everything else loads when
  it is needed.

Every change goes through the same courses, in order:

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

How much review a change gets is decided by a script, not a mood. A small, low-risk diff gets one
quick taste. A big one gets the full review. Anything touching auth, secrets, money, shell commands
or the network also gets the security reviewer.

And before writing any code, Nonna checks the pantry and stops at the first shelf that has it:

```
1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum code that works
```

The pantry sizes the dish, never the recipe. A test, a review and the recipe book are never
skipped to save lines. The layers in depth: [`docs/OVERVIEW.md`](docs/OVERVIEW.md) and the harness
index, [`.claude/README.md`](.claude/README.md).

## Come in, sit down

The most effort Nonna will ever ask of you:

```bash
git clone https://github.com/kapadias/keel /tmp/nonna
cp -r /tmp/nonna/.claude .claude && cp /tmp/nonna/CLAUDE.md CLAUDE.md
mkdir -p docs && cp /tmp/nonna/docs/STATUS.md docs/STATUS.md
chmod +x .claude/hooks/*.sh      # the pre-push gate installs itself at SessionStart
```

Or as a plugin: `/plugin marketplace add kapadias/keel`, then `/plugin install nonna@nonna`. A plugin
install carries less than a copy-in: it cannot bring the permission posture or the other eight
rules. See [`docs/INSTALL.md`](docs/INSTALL.md).

Then open the repo in [Claude Code](https://claude.com/claude-code) and say `/plan add OAuth
device-flow login`. Make the kitchen yours in three edits:

- **Your test gate:** copy a pack from [`stacks/`](stacks/) (python, typescript, go, rust), or edit
  [`.claude/skills/test/SKILL.md`](.claude/skills/test/SKILL.md).
- **Your tracker:** the issue prefix in [`.claude/rules/git-workflow.md`](.claude/rules/git-workflow.md).
- **Your formatter:** [`.claude/hooks/format.sh`](.claude/hooks/format.sh). Python, JS/TS, Go and
  Rust work out of the box.
- **Your critical paths (optional):** set `NONNA_CRITICAL_PATHS` to globs such as `src/billing/*`,
  and those paths always get the full review with security.

## Commands

Fifteen workflows, invoked as `/<name>`. The six marked **human-only** cannot be triggered by the
model at all. That is what makes "a human approves" a mechanism instead of a request.

| Workflow                     | Does                                                                                  |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| `/plan`                      | Restate the requirement, look for reuse, name the risks, split into reviewable steps. |
| `/tdd`                       | RED → GREEN → REFACTOR for one unit of behavior. The default way to build.            |
| `/implement`                 | Minimal, typed code against a failing test that already exists.                       |
| `/fix`                       | The quick lane for a small, reversible fix. `check-trivial.sh` decides who qualifies. |
| `/review`                    | Review sized by `review-lanes.sh`: one quick taste, the full review, plus security.   |
| `/audit`                     | Whole-repo sweep for over-building, ranked, plus the `debt:` ledger. Read-only.       |
| `/test`                      | Run your lint, type-check, test and coverage gate and summarize.                      |
| `/coverage`                  | Line and branch coverage, with the critical surface and its gaps up front.            |
| `/debug`                     | Reproduce, isolate, fix the cause, leave a regression test.                           |
| `/ship` **(human-only)**     | Full gate, conventional commit, push, PR to `develop` linked to the issue.            |
| `/release` **(human-only)**  | Promote `develop` to `main`: a human-gated release with tag and notes.                |
| `/rollback` **(human-only)** | Revert a bad change or roll back a deploy.                                            |
| `/sync` **(human-only)**     | Make every record of the system agree: tracker, docs, PR, harness index, memory.      |
| `/adr` **(human-only)**      | Write a numbered Architecture Decision Record with real alternatives.                 |
| `/intake` **(human-only)**   | Turn a raw idea or bug into a tidy, de-duplicated issue.                              |

Eight agents work in her kitchen: a planner, an implementer, a test engineer, two reviewers, an
explorer, a debugger and a router. Who runs on which model: [`docs/OVERVIEW.md`](docs/OVERVIEW.md).

## Development

Nonna tastes her own cooking first. Before any change lands:

```bash
bash tests/run.sh              # gate golden tests: each hook proven to block and to allow
python3 tests/harness_lint.py  # word budgets, stale counts, verdict format, hook wiring
```

CI runs both, plus shellcheck over every script. How to add a rule, skill or agent, and why most
additions belong on demand: [`CONTRIBUTING.md`](CONTRIBUTING.md). Vulnerabilities: [`SECURITY.md`](SECURITY.md).

## FAQ

**Is it just a prompt?**
No. A prompt cannot refuse a push. Hooks block, tests decide, and a linter keeps the rules short.

**Isn't it more expensive than a bare agent?**
Yes, per change. You are paying for the test, the review and the refusals. The numbers above say
what that buys and what it costs, including where it does not pay.

**What if I really need to ship without a test?**
You can. On a branch, behind a `debt:` marker that says when you will fix it. She will remember.

**Does it lock me into a language?**
No. Three small files name your tooling. Everything else is principle.

**Why Nonna?**
Because she doesn't care that it compiled.

## Credits

The decision ladder, the `debt:` marker convention, the over-engineering review tags and the
subagent context carrier are adapted from [ponytail](https://github.com/dietrichgebert/ponytail)
by Dietrich Gebert (MIT).

## License

[MIT](LICENSE) © 2026 Shashank Kapadia. Short, like a good recipe.

## Star History

<a href="https://www.star-history.com/#kapadias/keel&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=kapadias/keel&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=kapadias/keel&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=kapadias/keel&type=Date" />
 </picture>
</a>

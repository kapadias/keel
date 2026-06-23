<div align="center">

<img src="assets/keel-banner.svg" alt="Keel — a production-grade, token-efficient harness for Claude Code" width="100%">

<br/>

[![Built for Claude Code](https://img.shields.io/badge/Built%20for-Claude%20Code-D97757?style=for-the-badge)](https://claude.com/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-2b6cb0?style=for-the-badge)](LICENSE)
[![Language agnostic](https://img.shields.io/badge/Language-agnostic-2f855a?style=for-the-badge)](#make-it-yours)
[![Release](https://img.shields.io/badge/release-v0.1.0-1a3a52?style=for-the-badge)](docs/STATUS.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-d97757?style=for-the-badge)](CONTRIBUTING.md)

**The backbone that keeps an AI coding agent upright.**
A portable `.claude/` operating system that makes AI-assisted development
**disciplined, test-driven, review-gated, and safe** — without burning your context window.

[Quickstart](#quickstart) · [Philosophy](#the-three-principles) · [What's inside](#whats-inside) · [Token economy](#the-token-economy) · [Commands](#the-pipeline) · [Make it yours](#make-it-yours) · [Contributing](CONTRIBUTING.md)

</div>

---

## Why Keel?

An LLM coding agent is fast, tireless, and **confidently wrong** often enough to hurt you. Left
unstructured it will skip the test, swallow the error, refactor and change behavior in the same
breath, push to `main`, and quietly leak a secret into a log — and it will do all of it while sounding
certain.

**Keel is the structural backbone that keeps the agent upright.** A keel is the part of a ship that
resists capsizing under load; this harness is the part of your workflow that resists shipping
untested, unreviewed, or irreversible change under the pressure to move fast. It is a small, opinionated
set of **rules, agents, skills, commands, and hooks** that drop into any repository's `.claude/`
directory and encode *how the work gets done*.

It is distilled from a harness built for a real-capital systematic-trading operation — where a wrong
number moves money — and generalized for **any software project, in any language**.

> Keel is not a framework you import. It is a set of operating instructions for Claude Code: copy it in,
> adapt three things, and the agent starts working like a disciplined senior engineer.

---

## The three principles

Everything in Keel descends from three lines.

### 1. The LLM proposes; deterministic gates decide
An LLM may read code, draft changes, generate hypotheses, and explain. **Tests, types, linters, and
human review decide** whether any of it merges or acts. No unvalidated model output crosses a boundary
that touches production, money, or user data. The sharp test for any design:

> *"If this output is silently wrong, can it cause harm before a deterministic check catches it?"*
> If yes — put a gate between the LLM and the consequence.

### 2. Safety is lexicographically prior to speed
Irreversible and outward-facing actions — deploy, delete, force-push, publish, migrate — are gated
behind tests, review, and (when they widen blast radius) a human. Risk-*reducing* actions may be
automatic; risk-*increasing* actions are gated. When "safe" and "fast" disagree, **safe wins, always.**

### 3. Context is a budget — spend it deliberately
The always-on surface stays tiny; depth loads on demand. Token thrift is a first-class design goal —
and it is **never** paid for in quality. (See [The token economy](#the-token-economy).)

---

## The loop

Every change moves through these stages, in order. Speed comes from doing each well once — not from
skipping the ones that catch mistakes.

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

---

## What's inside

```
.claude/
├── rules/        always-on operating discipline — dense, short, paid every turn
├── agents/       specialists you delegate to (orchestrator, reviewers, explorer, …)
├── skills/       deep playbooks that load only when their trigger matches
├── commands/     the pipeline: /plan /tdd /review /ship /sync …
├── hooks/        deterministic guards around edits and pushes
└── settings.json denies reading secrets; wires the hooks
CLAUDE.md         the always-on root — the agent reads this first
docs/             STATUS.md (the live mirror) + Architecture Decision Records
```

| Layer | Loaded | Purpose |
|---|---|---|
| `CLAUDE.md` + `rules/` | **Always** | The dense, short policy the agent obeys every turn. |
| `skills/` | **On demand** | Long playbooks that cost nothing until their trigger matches. |
| `commands/` | **On invoke** | Repeatable workflows encoded once, so you never re-explain them. |
| `agents/` | **On delegate** | Specialists that spend *their own* context and return conclusions. |
| `hooks/` | **On event** | Deterministic enforcement on edit and on push. |

---

## The token economy

Most "AI dev setups" fail the same way: they stuff every instruction into one always-on file. Every
token in that file is re-read on **every** turn, the window fills, and the agent gets duller as the
task gets longer. Keel is built the other way — **progressive disclosure**:

| | Always-on (paid every turn) | On-demand (paid only when needed) |
|---|---|---|
| **What** | `CLAUDE.md` + 8 rules | 5 skills + 10 commands + 7 agents |
| **Footprint** | ~510 lines · **≈5k tokens** | ~930 lines · **≈10k tokens** |
| **When loaded** | Every request | Only when a trigger matches, a command runs, or a subagent is dispatched |

So **two-thirds of Keel's guidance never touches your main context** until the moment it is relevant.
The mechanisms:

- **Tiny always-on core.** Rules state a principle in a sentence and *link* to the detail — they never
  inline it. The whole standing policy is ~5k tokens, not 50k.
- **Skills load on a trigger.** A 2,000-token debugging playbook costs zero until you are debugging.
- **Commands encode workflows once.** `/ship` runs the whole gate-commit-PR-sync sequence; you don't
  re-describe it each time.
- **Subagents do the fan-out.** Need to search 40 files? The `explorer` agent (on a cheap model) burns
  *its* context and hands back three `path:line` references and an answer — not the file dumps. Your
  main thread keeps the conclusion.
- **Model-tier routing.** Haiku for mechanical fan-out, Sonnet for the build, Opus for review and hard
  reasoning. Cost matched to depth.

> **The one hard line:** token thrift never justifies skipping a test, a review, a validation step, or
> a safety gate. Save tokens on *how you find and present information* — never on the correctness and
> safety of the work. See [`.claude/rules/token-economy.md`](.claude/rules/token-economy.md).

---

## Quickstart

Keel is files, not a dependency. Adopt it in under a minute.

```bash
# From the root of your repository:
git clone https://github.com/kapadias/keel /tmp/keel

# Copy the harness and the root guidance into your repo:
cp -r /tmp/keel/.claude .claude
cp /tmp/keel/CLAUDE.md CLAUDE.md
mkdir -p docs && cp /tmp/keel/docs/STATUS.md docs/STATUS.md

# Make the hooks executable, and install the Definition-of-Done pre-push gate:
chmod +x .claude/hooks/*.sh
ln -sf ../../.claude/hooks/require-status-sync.sh .git/hooks/pre-push
```

Then open the repo in **[Claude Code](https://claude.com/claude-code)** and try:

```
/plan add OAuth device-flow login
/tdd
/review
/ship
```

That's it — the agent now plans before coding, writes the failing test first, reviews before merge,
and refuses to mark work done while a mirror is out of sync. Next, [make it yours](#make-it-yours).

---

## The pipeline

Ten commands cover the development loop. Invoke them with `/<name>` in Claude Code.

| Command | Does |
|---|---|
| `/plan` | Restate the requirement, research reuse, surface risks, decompose into reviewable steps. |
| `/tdd` | Run RED → GREEN → REFACTOR for a unit of behavior. The default way to build. |
| `/implement` | Write minimal, typed, reviewable code against an existing failing test. |
| `/review` | Path-aware parallel review — correctness always, security when the change warrants it. |
| `/test` | Run the project's lint + type-check + test + coverage gate and summarize. |
| `/debug` | Reproduce → isolate → root-cause → fix the cause → leave a regression test. |
| `/ship` | Full gate → conventional commit → push → PR to `develop`, linked to the issue. |
| `/sync` | Reconcile the five mirrors so every record of the system agrees. |
| `/adr` | Write a numbered Architecture Decision Record with real alternatives. |
| `/intake` | Turn a raw idea or bug into a well-formed, de-duplicated tracked issue. |

---

## The crew

Seven specialist agents, each model-tiered so you never burn a frontier model on mechanical work.

| Agent | Model | Role |
|---|---|---|
| `orchestrator` | Opus | Router. Decomposes a request and sequences the loop. Read-only; it plans and delegates. |
| `implementer` | Sonnet | Builds features to make failing tests pass. The bulk of engineering. |
| `test-engineer` | Sonnet | Writes the failing tests that pin behavior, plus golden and property tests. |
| `code-reviewer` | Opus | Independent, read-only, adversarial correctness review before merge. |
| `security-reviewer` | Opus | Read-only security review — injection, secrets, authz, supply chain. |
| `explorer` | Haiku | Read-only fan-out search. Returns conclusions, not file dumps. The token-saver. |
| `debugger` | Sonnet | Reproduce, isolate, root-cause, and fix — the cause, not the symptom. |

**On-demand skills** deepen the agents when triggered: `tdd-workflow`, `code-review`, `debugging`,
`refactoring`, `api-design`.

---

## Safety & enforcement

Three hooks turn the rules into deterministic guards — not suggestions:

- **`guard-branch.sh`** (pre-edit) — warns when you start editing on `main` / `master` / `develop`.
- **`format.sh`** (post-edit) — auto-formats the file you just touched, using whatever formatter your
  project provides (ruff, prettier, gofmt, rustfmt — best-effort, never blocking).
- **`require-status-sync.sh`** (pre-push) — blocks a code push that forgot to update `docs/STATUS.md`,
  enforcing the Definition of Done.

`settings.json` also denies the agent from reading `.env`, `secrets/**`, `*.pem`, and private keys —
secrets never enter the context window in the first place.

---

## Make it yours

Keel is language-agnostic. Three edits adapt it to any stack:

1. **Your test gate** → edit [`.claude/commands/test.md`](.claude/commands/test.md) and
   [`/ship`](.claude/commands/ship.md) with your real lint/type/test commands.
2. **Your tracker** → set your issue-id prefix and branch convention in
   [`.claude/rules/git-workflow.md`](.claude/rules/git-workflow.md).
3. **Your formatter** → point [`.claude/hooks/format.sh`](.claude/hooks/format.sh) at your tool (it
   already handles Python, JS/TS, Go, and Rust out of the box).

Everything else is principle, not tooling — it transfers unchanged.

---

## Repository structure

```
keel/
├── CLAUDE.md                  # always-on root guidance (read first)
├── README.md                  # you are here
├── LICENSE                    # MIT
├── CONTRIBUTING.md            # how to extend the harness
├── SECURITY.md                # how to report a vulnerability
├── .claude/
│   ├── README.md              # harness index
│   ├── settings.json          # secret-deny + hook wiring
│   ├── rules/                 # 8 always-on rules
│   ├── agents/                # 7 specialists
│   ├── skills/                # 5 on-demand playbooks
│   ├── commands/              # 10 pipeline commands
│   └── hooks/                 # 3 enforcement scripts
├── docs/
│   ├── STATUS.md              # the living state mirror
│   └── adr/                   # Architecture Decision Records
├── assets/                    # banner
└── .github/                   # CI + PR template
```

---

## FAQ

**Is this a library or a CLI?** Neither. It is a set of Markdown + shell files that configure
[Claude Code](https://claude.com/claude-code). There is nothing to install and nothing to import.

**Does it lock me into a language or framework?** No. The rules are principles; only three small files
reference concrete tooling, and those are meant to be edited (see [Make it yours](#make-it-yours)).

**Why "Keel"?** A keel is the backbone that keeps a ship upright under load. This harness keeps a coding
agent upright under the pressure to move fast.

**Will this slow me down?** It front-loads the work that prevents rework: a plan, a failing test, a
review. Net, it is faster — and far safer — than shipping and debugging in production.

---

## Contributing

Issues and PRs are welcome. Keel itself is built with Keel — see
[`CONTRIBUTING.md`](CONTRIBUTING.md) for the style guide, the frontmatter shapes, and how to add a
rule, skill, command, or agent (and why most additions should be on-demand, not always-on).

## Security

See [`SECURITY.md`](SECURITY.md). In short: no secrets in code, logs, or prompts; report
vulnerabilities privately.

## License

[MIT](LICENSE) © 2026 Shashank Kapadia.

---

<div align="center">

**Keel** — the LLM proposes; deterministic gates decide.

<sub>Built for <a href="https://claude.com/claude-code">Claude Code</a>. Distilled from a real-capital trading harness, generalized for everyone.</sub>

</div>

# Keel — how the pieces fit

The detail behind the [README](../README.md): the token economy, the layers, the crew, the gates,
and the repository layout. The harness itself is indexed in [`.claude/README.md`](../.claude/README.md).

## The token economy

Most "AI dev setups" fail the same way: they stuff every instruction into one always-on file. Every
token in that file is re-read on **every** turn, the window fills, and the agent gets duller as the
task gets longer. Keel is built the other way — **progressive disclosure**:

|                 | Always-on (paid every turn)                                                                                                                              | On-demand (paid only when needed)                                         |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **What**        | `CLAUDE.md` + 9 rules, plus the name+description of each skill, agent and workflow                                                                       | 12 skill playbooks + 15 pipeline workflows + 8 agents — bodies only       |
| **Footprint**   | **~7.1k tokens** — 3,679 words of prose (3,700-word budget) + ~1.1k tokens of descriptions (5,600-char budget), both enforced by `tests/harness_lint.py` | the bulk of Keel — loaded only when relevant                              |
| **When loaded** | Every request                                                                                                                                            | Only when a trigger matches, a workflow runs, or a subagent is dispatched |

The six side-effecting workflows (`/ship`, `/release`, `/rollback`, `/adr`, `/sync`, `/intake`) carry
`disable-model-invocation: true`, so they cost **zero** always-on tokens — and Claude cannot invoke
them at all. Only you can.

## What's inside

| Layer                  | Loaded          | Purpose                                                                           |
| ---------------------- | --------------- | --------------------------------------------------------------------------------- |
| `CLAUDE.md` + `rules/` | **Always**      | The dense, short policy the agent obeys every turn.                               |
| `skills/`              | **On demand**   | Playbooks that cost nothing until triggered, plus the `/name` pipeline workflows. |
| `agents/`              | **On delegate** | Specialists that spend _their own_ context and return conclusions.                |
| `hooks/`               | **On event**    | Deterministic enforcement on edit and on push.                                    |

## The crew

Eight specialist agents, each model-tiered so you never burn a frontier model on mechanical work.

| Agent               | Model  | Role                                                                                    |
| ------------------- | ------ | --------------------------------------------------------------------------------------- |
| `orchestrator`      | Opus   | Router. Decomposes a request and sequences the loop. Read-only; it plans and delegates. |
| `planner`           | Opus   | Read-only. Turns a request into a written plan — risks, decomposition, a gate per step. |
| `implementer`       | Sonnet | Builds features to make failing tests pass. The bulk of engineering.                    |
| `test-engineer`     | Sonnet | Writes the failing tests that pin behavior, plus golden and property tests.             |
| `code-reviewer`     | Opus   | Independent, read-only correctness review; emits a machine-checkable JSON verdict.      |
| `security-reviewer` | Opus   | Read-only security review — injection, secrets, authz, supply chain.                    |
| `explorer`          | Haiku  | Read-only fan-out search. Returns conclusions, not file dumps. The token-saver.         |
| `debugger`          | Opus   | Reproduce, isolate, root-cause, and fix — the cause, not the symptom.                   |

**On-demand skills** deepen the agents when triggered — most bundling runnable scripts/templates/
references: `tdd-workflow`, `code-review`, `debugging`, `refactoring`, `api-design`, `security-review`,
`migration-safety`, `observability`, `concurrency-performance`, `supply-chain`, `fast-lane`, `lean`
(the decision ladder in depth, with `check-debt.sh`).

## Safety & enforcement

Hooks turn the rules into deterministic guards — gates, not suggestions:

- **`guard-branch.sh`** — **blocks** `git commit` / `git push` to `main` / `master` / `develop` (warns
  on edits there), plus `--all` / `--mirror` and `+refspec` force pushes. The "never commit to a
  protected branch" rule, actually enforced.
- **`secret-scan.sh`** — **blocks** any edit/write that introduces a high-confidence secret (AWS /
  GitHub / Slack / Google keys, private-key blocks, hardcoded credentials), and Bash reads/copies of
  secret files (`cat .env`) — parity with the Read deny list.
- **`format.sh`** — auto-formats the file you just touched (ruff / prettier / gofmt / rustfmt —
  best-effort, never blocking).
- **`require-status-sync.sh`** (pre-push, **auto-installed at `SessionStart`** — warns instead of
  overwriting a foreign pre-push hook) — blocks a code push that skips `docs/STATUS.md` or that
  introduces a secret (no fixture exemption at push time). The Definition of Done, enforced.

`settings.json` denies reading `.env`, `secrets/**`, `*.pem`, `*.key`, `~/.ssh`, `~/.aws`, and more —
and denies `git push --force`. The harness even **tests its own gates**: `bash tests/run.sh` runs
golden tests proving each one blocks vs. allows, and CI fails if any gate regresses.

See [`SECURITY.md`](../SECURITY.md) for how to report a vulnerability privately.

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
│   ├── .claude-plugin/        # plugin manifest (plugin.json)
│   ├── rules/                 # 9 always-on rules (00-core is the constitution)
│   ├── agents/                # 8 specialists
│   ├── skills/                # 12 playbooks + 15 pipeline workflows (6 human-only)
│   └── hooks/                 # 9 enforcing hooks over 7 events + lib/ + hooks.json
├── tests/                     # gate golden tests + harness self-validation
├── stacks/                    # python · typescript · go · rust gate packs
├── docs/
│   ├── STATUS.md              # the living state mirror
│   ├── ROADMAP.md             # the v0.2 plan
│   └── adr/                   # Architecture Decision Records
├── .claude-plugin/            # marketplace.json (plugin distribution)
├── assets/                    # banner
└── .github/                   # CI + PR template
```

# Keel self-tests — the harness held to its own bar

Keel's thesis is _deterministic gates decide_. A harness that preaches gates must
**prove its own gates fire** — otherwise it is the very "green suite that asserts
nothing" it warns against ([ADR 0002](../docs/adr/0002-llm-proposes-gates-decide.md)).
These tests are [`boundaries.md`](../.claude/rules/boundaries.md) applied to Keel
itself: if a gate is silently wrong, CI goes red.

## What runs

| File                                 | What it proves                                                         | How                                               |
| ------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------- |
| [`run.sh`](run.sh)                   | **Every gate blocks vs. allows correctly** — the WS7 eval scenarios.   | 28 golden tests over real hook/script invocations |
| [`harness_lint.py`](harness_lint.py) | **The harness is internally consistent** — structural self-validation. | static checks over `.claude/` + docs              |

### `run.sh` — gate golden tests

Exercises each deterministic gate with fixed inputs and asserts the exit code:

- **secret detection** (`lib/secret-patterns.sh`): catches AWS/GitHub/Slack/Google
  keys and hardcoded assignments; ignores placeholders and env-var refs.
- **secret-scan** (PreToolUse): blocks a write that introduces a secret; allows
  clean writes and sample secrets under `test/fixture/example` paths.
- **guard-branch** (PreToolUse): blocks `git commit`/`git push` on `main`/`master`/
  `develop`; allows work on a feature branch.
- **require-status-sync** (pre-push): blocks a code push without a `docs/STATUS.md`
  update or that introduces a secret; allows a synced push.
- **session-start**: emits context and auto-installs the pre-push hook.
- **check-review** (review verdict gate): blocks on `request_changes` or any
  CRITICAL/HIGH finding; fails closed on invalid JSON.
- **dep-audit** (supply-chain): exits non-zero when a required scanner is missing
  (a skipped scan is not a pass).

### `harness_lint.py` — structural self-validation

Fails the build on: read-only agents granting mutating tools, invalid model tiers,
skills missing a trigger, wired hooks absent on disk, dead intra-repo markdown
links, domain-specific vocabulary in a domain-agnostic harness, and malformed
plugin manifests.

## Run it

```bash
bash tests/run.sh        # gate golden tests  (exit non-zero on any failure)
python3 tests/harness_lint.py   # structural self-validation
```

Both run in CI on every push and pull request (`.github/workflows/ci.yml`),
alongside `shellcheck` over every script. Adopters wire their own
lint/type/test/coverage gate as additional jobs — see [`stacks/`](../stacks/).

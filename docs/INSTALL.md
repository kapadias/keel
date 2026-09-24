# Installing Nonna

One command, from the root of a git repository:

```bash
curl -fsSL https://raw.githubusercontent.com/kapadias/keel/main/install.sh | bash
```

That installs for Claude Code. For another agent, name it (several at once: `--host cursor,agents`):

| Host                                                                      | Command                           | Rules file written                |
| ------------------------------------------------------------------------- | --------------------------------- | --------------------------------- |
| Claude Code                                                               | `… \| bash`                       | `CLAUDE.md` + `.claude/`          |
| Codex, Zed, Amp, opencode, Roo Code, Jules, Junie, any `AGENTS.md` reader | `… \| bash -s -- --host agents`   | `AGENTS.md`                       |
| Cursor                                                                    | `… \| bash -s -- --host cursor`   | `.cursor/rules/nonna.mdc`         |
| GitHub Copilot                                                            | `… \| bash -s -- --host copilot`  | `.github/copilot-instructions.md` |
| Gemini CLI                                                                | `… \| bash -s -- --host gemini`   | `GEMINI.md`                       |
| Windsurf                                                                  | `… \| bash -s -- --host windsurf` | `.windsurf/rules/nonna.md`        |
| Cline                                                                     | `… \| bash -s -- --host cline`    | `.clinerules/nonna.md`            |
| Kiro                                                                      | `… \| bash -s -- --host kiro`     | `.kiro/steering/nonna.md`         |
| All of them                                                               | `… \| bash -s -- --host all`      | all of the above                  |

Every host gets the same thing:

- **The house rules**, generated from `.claude/rules/00-core.md` by `hosts/build.py`, plus the full
  rules under `.claude/rules/` for depth.
- **Git hooks that enforce them for any agent**: `pre-commit` refuses a commit on `main`, `master` or
  `develop`, a staged secret file, and a staged credential; `pre-push` refuses a code push that leaves
  `docs/STATUS.md` stale, and any secret.
- **A blank `docs/STATUS.md`** and, if it finds `pyproject.toml`, `package.json`, `go.mod` or
  `Cargo.toml`, that stack's test-gate permissions.

It never overwrites a file or a git hook that already exists; it lists what it left alone. If you
use a hook manager (a custom `core.hooksPath`), it tells you which scripts to point it at. Pin a
release with `curl … | NONNA_REF=<tag> bash`. Prefer to read before you pipe? `curl -fsSLO …/install.sh`, read it,
then `bash install.sh`.

Claude Code gets more than the other hosts: the tool-level hooks (a write is scanned before it
lands, a turn cannot end with the status doc stale, a reviewer's verdict is machine-checked), the
agents, and the fifteen workflows. On other hosts the rules and the git hooks do the work; the
benchmark showed the rules are what kept agents off `main` and away from secrets.

## Option B — install as a plugin (versioned, shareable)

```
/plugin marketplace add kapadias/keel
/plugin install nonna@nonna
```

A plugin install brings the agents, skills, and hooks
(see [ADR 0006](adr/0006-distribute-as-plugin.md) and
[ADR 0007](adr/0007-plugin-install-is-not-equivalent.md)).

### Known limitation 1 — only `00-core.md` rides along

Claude Code's plugin schema has **no `rules` component**, and the root `CLAUDE.md` lives outside the
plugin root. `rules/00-core.md` — the constitution: the three principles, the loop, the ladder, the
never-list — rides `SessionStart` into the parent session and `SubagentStart` into every subagent, so
that much of the operating discipline reaches the agent regardless. The other eight
`.claude/rules/*.md` files and `CLAUDE.md` do **not** load, even though those files sit inside the
published plugin directory. The agents, skills and hooks all arrive; the rest of the policy surface
that tells the agent _how to work_ does not.

Until that is closed, copy the discipline in alongside the plugin:

```bash
git clone --depth 1 https://github.com/kapadias/keel /tmp/nonna
mkdir -p .claude/rules && cp -r /tmp/nonna/.claude/rules/. .claude/rules/
cp /tmp/nonna/CLAUDE.md CLAUDE.md
```

### Known limitation 2 — the permission posture is NOT injected

The plugin mechanism does not propagate `settings.json` permissions to the host project. A fresh
plugin install therefore has **weaker secret protection** than a standalone copy until you add
Nonna's deny-list to your own project settings. This step is manual and mechanical — copy the
`permissions.deny` block below (kept in sync with
[`.claude/settings.json`](../.claude/settings.json)) into your project's
`.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Read(./**/.env)",
      "Read(./**/.env.*)",
      "Read(./**/secrets/**)",
      "Read(./**/*.pem)",
      "Read(./**/*.key)",
      "Read(./**/*.p12)",
      "Read(./**/id_rsa*)",
      "Read(./**/.ssh/**)",
      "Read(./**/.aws/**)",
      "Read(./**/.npmrc)",
      "Read(./**/*.p8)",
      "Read(./**/*.pfx)",
      "Read(./**/*.jks)",
      "Read(./**/kubeconfig)",
      "Read(./**/credentials)",
      "Bash(git push --force:*)",
      "Bash(git push --force-with-lease:*)",
      "Bash(git push -f:*)"
    ]
  }
}
```

### What a plugin install DOES get right

- **The constitution reaches every agent.** `SessionStart` carries `rules/00-core.md` — the three
  principles, the loop, the decision ladder, the never-list — into the parent session, and
  `SubagentStart` carries it into each subagent (`SessionStart` context is parent-only). The other
  eight rules still need the copy-in above.
- The **Definition-of-Done pre-push hook self-installs** from `${CLAUDE_PLUGIN_ROOT}` at
  `SessionStart` — no manual symlink. If it cannot be located, the session says so rather than
  going quiet.
- **Gate scripts stay reachable.** `SessionStart` announces the resolved harness root, so
  `/review`, `/ship` and `/fix` can invoke `check-review.sh` and `check-trivial.sh` wherever the
  plugin is installed. Their first run may prompt for approval, because the absolute plugin path
  cannot be pre-declared in `allowed-tools`.

## After either path

1. Wire the test gate: pick your language pack under [`stacks/`](../stacks/README.md) — copy its
   `settings.local.json` and adapt `/test`'s commands to your stack.
2. Open the repo in Claude Code and try `/plan`, `/tdd`, `/review`, `/ship` — or `/fix` for a
   trivial change (the fast lane's eligibility is decided by `check-trivial.sh`, not by prose).

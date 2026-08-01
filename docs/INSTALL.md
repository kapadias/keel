# Installing Keel

Keel is files, not a dependency. Two supported paths. **They are not equivalent** — a plugin install
cannot carry the always-on rules or the permission posture (see the limitations below). Option A is
the complete harness; Option B trades completeness for versioned, shareable distribution.

## Option A — copy it in (standalone)

```bash
# From the root of your repository:
git clone https://github.com/kapadias/keel /tmp/keel
cp -r /tmp/keel/.claude .claude
cp /tmp/keel/CLAUDE.md CLAUDE.md
mkdir -p docs && cp /tmp/keel/docs/STATUS.md docs/STATUS.md
chmod +x .claude/hooks/*.sh
```

The pre-push Definition-of-Done gate self-installs at `SessionStart` (see
[ADR 0004](adr/0004-gates-as-code.md)). If your repo already has a `pre-push` hook, Keel warns
instead of overwriting it — chain `.claude/hooks/require-status-sync.sh` from your hook manually.

## Option B — install as a plugin (versioned, shareable)

```
/plugin marketplace add kapadias/keel
/plugin install keel@keel
```

A plugin install brings the agents, skills, commands, and hooks
(see [ADR 0006](adr/0006-distribute-keel-as-plugin.md) and
[ADR 0007](adr/0007-plugin-install-is-not-equivalent.md)).

### Known limitation 1 — the always-on rules are NOT loaded

Claude Code's plugin schema has **no `rules` component**, and the root `CLAUDE.md` lives outside the
plugin root. A plugin install therefore loads **none** of Keel's operating discipline — the eight
`.claude/rules/*.md` files and `CLAUDE.md` — even though those files sit inside the published plugin
directory. The agents, skills, commands and hooks all arrive; the policy surface that tells the agent
_how to work_ does not.

Until that is closed, copy the discipline in alongside the plugin:

```bash
git clone --depth 1 https://github.com/kapadias/keel /tmp/keel
mkdir -p .claude && cp -r /tmp/keel/.claude/rules .claude/rules
cp /tmp/keel/CLAUDE.md CLAUDE.md
```

### Known limitation 2 — the permission posture is NOT injected

The plugin mechanism does not propagate `settings.json` permissions to the host project. A fresh
plugin install therefore has **weaker secret protection** than a standalone copy until you add
Keel's deny-list to your own project settings. This step is manual and mechanical — copy the
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

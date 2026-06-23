# Security Policy

Keel ships scripts and hooks that run on contributors' machines, so we take reports seriously and
respond quickly.

## Reporting a vulnerability

**Do not open a public issue for a security problem.** Report it privately:

- Preferred: open a **GitHub Security Advisory** on `kapadias/keel`
  (*Security → Report a vulnerability*).
- Or contact the maintainer directly (Shashank Kapadia) rather than filing a public issue or PR.

Please include what you found, how to reproduce it, and the impact you see. We will acknowledge the
report, work a fix, and coordinate disclosure with you.

## Scope

In scope is the harness itself — the **hooks** (`.claude/hooks/*.sh`), the **commands/agents/skills**,
and **`settings.json`**, particularly anything that executes, gates a tool call, or touches the
filesystem. Issues in your own project's code or in third-party dependencies you wire in are out of
scope here; report those to their respective owners.

## Secrets posture

Keel is built to keep secrets out of the loop:

- **No secrets in code, logs, or prompts.** Keys and tokens live in a secret manager or a
  git-ignored `.env`, never committed and never echoed into agent context.
- **`settings.json` denies reading `.env` and `secrets/**`,** so the agent cannot pull credentials into
  the context window or a transcript.
- **If a secret is ever exposed, rotate it** — assume it is burned. Deleting the commit is not
  sufficient; treat the value as compromised and issue a new one.

## Thank you

Responsible disclosure protects everyone who relies on Keel. We appreciate the time and care it takes —
thank you.

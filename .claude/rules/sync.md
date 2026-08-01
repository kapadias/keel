# Rule: Sync — the Definition of Done

A unit of work is **done** only when every mirror of reality agrees. Merged code is not done; a drifted
mirror is a silent lie about the state of the system, and that lie is where incidents are born.

## The five mirrors

The list is in [00-core.md](./00-core.md). Update them **together**, as part of completing the work —
not "later." What each one owes:

1. **Tracker** — move the issue to its real status; paste the PR link onto it.
2. **Docs** — `docs/STATUS.md` always; `README`/product docs **if behavior or usage changed**; an
   ADR (`/adr`) **if a non-trivial decision was made**.
3. **Git / PR** — branch + PR open and linked to the issue ([git-workflow.md](./git-workflow.md)).
4. **Harness** (`.claude/`) — **if you changed an agent, skill, command, rule, or hook**, update
   `.claude/README.md` and `CLAUDE.md` so the index matches reality.
5. **Memory** — durable decisions only: the why behind a choice, a rejected alternative, a learned
   invariant — so it survives a context reset.

A mirror you _considered and deliberately skipped_ is synced; one you forgot is drift. Say which.

## Enforcement

- A pre-push hook (`require-status-sync.sh`) blocks code pushes that do not touch `docs/STATUS.md`.
  Keep it current; do not bypass it.
- Run `/sync` to reconcile drift across the mirrors at any time, and before shipping (`/ship`).

Never mark a task complete in one mirror while another contradicts it.

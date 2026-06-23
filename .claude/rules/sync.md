# Rule: Sync — the Definition of Done

A unit of work is **done** only when every mirror of reality agrees. Merged code is not done; a drifted
mirror is a silent lie about the state of the system, and that lie is where incidents are born.

## The five mirrors

Update these **together**, as part of completing the work — not "later."

1. **Issue tracker** — the system of record. Move the issue to its correct status; paste the PR link
   onto it.
2. **Docs** (`docs/`)
   - `docs/STATUS.md` — always update what changed and the current state.
   - `README` / product docs — update **if behavior or usage changed**.
   - `docs/adr/` — add an ADR **if a non-trivial decision was made** (`/adr`).
3. **Git / PR** — branch + PR open and linked to the issue (see [git-workflow.md](./git-workflow.md)).
4. **Harness** (`.claude/`) — **if you changed an agent, skill, command, rule, or hook**, update
   `.claude/README.md` and `CLAUDE.md` so the index matches reality.
5. **Memory** — record **durable decisions**: the why behind a choice, a rejected alternative, a
   learned invariant — so it survives a context reset.

## Checklist (per completed unit)

- [ ] Tracker status updated + PR linked
- [ ] `docs/STATUS.md` updated
- [ ] Docs/README updated *(if usage changed)*
- [ ] ADR added *(if a decision was made)*
- [ ] Branch + PR open and linked
- [ ] `.claude/README.md` + `CLAUDE.md` updated *(if the harness changed)*
- [ ] Durable decisions captured in memory
- [ ] Tests green (see [testing.md](./testing.md))

## Enforcement

- A pre-push hook (`require-status-sync.sh`) blocks code pushes that do not touch `docs/STATUS.md`.
  Keep it current; do not bypass it.
- Run `/sync` to reconcile drift across the mirrors at any time, and before shipping (`/ship`).

Never mark a task complete in one mirror while another contradicts it.

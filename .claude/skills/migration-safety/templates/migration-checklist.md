# Migration Checklist — <migration id / slug>

Copy this into the PR for any schema change, backfill, or destructive migration. Every box is a gate,
not a suggestion. If a box is N/A, write _why_ — don't delete it. See `../SKILL.md` and
`.claude/rules/safety.md`.

## 1. Classify

- [ ] **Type:** ☐ additive (expand) ☐ backfill (migrate) ☐ destructive (contract/drop/rename)
- [ ] **Blast radius:** which tables, how many rows, which services read/write them?
- [ ] **Reversible?** ☐ yes (down path tested) ☐ no → must be its own release + backup first
- [ ] This release does **not** both change the schema _and_ depend on the change (split if it does)

## 2. Compatibility (old and new code run at the same time)

- [ ] New columns are **nullable or defaulted** — old code can insert without them
- [ ] No `NOT NULL` / tightened constraint added in the same step as the column
- [ ] No consumer relies on `SELECT *` / column order that this change shifts
- [ ] Deploy order written down: **readers → writers → remove old path**
- [ ] Old code's test suite passes against the post-migration schema

## 3. Lock & online safety

- [ ] Known lock level + expected duration for each DDL statement on a production-sized table
- [ ] Index builds use the **non-blocking** path (`CONCURRENTLY` / `ALGORITHM=INPLACE, LOCK=NONE`)
- [ ] `lock_timeout` / `statement_timeout` set so the migration **fails fast**, never queues
- [ ] Large `UPDATE`/`DELETE` is **batched**, not one statement
- [ ] Replica lag watched; migration throttles to protect prod

## 4. Backfill (if any)

- [ ] **Idempotent** — safe to run twice (`WHERE new_col IS NULL` / upsert on stable key)
- [ ] **Batched** with a bounded size and a high-water mark so it **resumes** after interruption
- [ ] Runs **outside** the schema-change transaction (no held DDL locks)
- [ ] Throttled; tested on a copy; correctness checked against a known row set (golden)

## 5. Dual-write window (if reads are transitioning)

- [ ] App writes **both** old and new shape during the window
- [ ] New write is idempotent and reconcilable
- [ ] **Parity check** (counts/checksums old vs new) green before trusting the new shape
- [ ] Window is short, observed, and has a removal step scheduled

## 6. Reversibility & rollback

- [ ] `down` migration written and **tested** on a copy (for reversible steps)
- [ ] Destructive step: **verified backup taken first**, runs in its own release
- [ ] Code rollback does **not** require schema rollback (expand/contract upheld)
- [ ] Rollback procedure written in the PR — what to run, who to call

## 7. Verify before prod (`.claude/rules/testing.md`)

- [ ] `up → down → up` round-trip green in CI; data survives
- [ ] **Dry-run on a production-sized clone** — lock duration and timeouts observed
- [ ] Monitoring/alerts in place to catch errors during and right after rollout
- [ ] ADR written if this involved a non-trivial decision (`/adr`)

## Rollout plan (fill in)

| Step | Action                            | Reversible?           | Verify          |
| ---- | --------------------------------- | --------------------- | --------------- |
| 1    | Expand: …                         | yes                   | …               |
| 2    | Migrate/backfill: …               | yes                   | parity check    |
| 3    | Deploy new code (reads new shape) | yes (revert code)     | error rate flat |
| 4    | Contract: drop old …              | **no** — backup first | …               |

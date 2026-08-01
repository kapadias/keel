---
name: migration-safety
description: Changing a database schema, backfilling or transforming data, or any destructive migration — drop/rename/type-change, large UPDATE, dual-write rollout, zero-downtime, reversibility.
---

# Migration Safety

A migration runs **against live data while old and new code are both deployed**. The schema you change
is the one your running app is mid-flight querying. Treat every migration as outward-facing and
irreversible-by-default: plan the rollback _before_ the rollout, and never let a single deploy both
change the schema and depend on the change (`.claude/rules/safety.md`).

Work the bundled `templates/migration-checklist.md` for any non-trivial migration — it is the gate.

## Expand → Migrate → Contract — the one pattern that makes schema change safe

Never rename or drop in place; old code is still reading the old shape. Split every breaking change
into separate, independently-deployable releases:

1. **Expand** — add the new shape _additively and nullable_: new column/table/index, no destructive
   change. Old code ignores it; new code can write it. Safe to deploy and roll back freely.
2. **Migrate** — backfill existing rows (idempotent, batched), and **dual-write**: app writes both
   old and new shape so they stay consistent while reads transition old → new. Verify parity.
3. **Contract** — only after new code is fully deployed and reads are off the old shape: drop the
   old column/table, stop the dual-write. This is the irreversible step — it gets its own release and
   a backup taken first.

A rename = add new (expand) + backfill + dual-write (migrate) + drop old (contract). Three deploys,
each reversible until the last. Collapsing them is how you take prod down.

## Backward / forward compatibility — the deploy is never atomic

During any rollout, **old code and new code run simultaneously** (rolling deploy, canary, a straggler
pod). The schema must satisfy both:

- **New column must be nullable or have a default** — old code inserts rows without it.
- **Never `NOT NULL` on add** in one step; add nullable → backfill → add the constraint later.
- **Old code must tolerate new columns** (`SELECT *` consumers break on shape change — pin columns).
- **Readers ship before writers; writers ship before the old path is removed.** Order deploys so no
  version ever sees a shape it can't handle.

## Online / zero-downtime DDL — know your engine's lock behavior

The killer is the migration that takes an `ACCESS EXCLUSIVE` / table lock and blocks all queries while
it rewrites the table. Before running DDL, know what it locks and for how long:

- **Adding an index:** use the non-blocking path (`CREATE INDEX CONCURRENTLY` in Postgres,
  `ALGORITHM=INPLACE, LOCK=NONE` in MySQL/InnoDB). The plain form locks writes for the whole build.
- **Adding a column with a volatile default** can rewrite the whole table under lock on older engines
  — add the column, then backfill the value separately.
- **Set a short `lock_timeout`/`statement_timeout`** so a migration that can't get its lock fails fast
  instead of queuing behind it and stalling every request (fail closed, not open).
- **Large `UPDATE`/`DELETE` in one statement** holds locks and bloats the transaction log — batch it.

## Idempotent, batched backfills

A backfill will be interrupted (timeout, deploy, OOM) and re-run. It must be **safe to run twice and
resumable**, never one giant transaction:

- **Batch by key range** with a bounded size and a short pause between batches; track a high-water
  mark so a restart resumes, not restarts.
- **Idempotent writes:** `UPDATE ... WHERE new_col IS NULL` or upsert on a stable key — re-processing
  a row is a no-op, not a double-apply (`.claude/rules/safety.md`).
- **Throttle to protect prod** — a backfill that saturates IO is an outage. Watch replica lag.
- **Run it outside the schema-change transaction** so a slow backfill never holds DDL locks.

## Dual-write windows — keep two shapes consistent in flight

While reads move from old to new, writes must hit **both**, or the shape you're migrating to drifts:

- Write old + new in the **same transaction** where possible; if not, make the new write idempotent
  and reconcilable, and detect divergence.
- **Reconcile, don't assume** — run a parity check (counts/checksums old vs new) before you trust the
  new shape and before Contract. Halt on unexplained divergence (`.claude/rules/safety.md`).
- Keep the window **short and observed**; a forgotten dual-write rots silently for months.

## Reversibility & rollback — written before you run it

Every migration has a **tested down path or an explicit, documented reason it's one-way** (you can't
un-drop a column — which is exactly why Contract is last and gated by a backup).

- **Reversible steps (expand, backfill):** ship the `down` and test it on a copy.
- **Irreversible steps (contract/drop):** take a verified backup first, run in its own release, and
  confirm the new path has been live and healthy long enough that rollback is unlikely.
- Rollback of _code_ must not require rollback of _schema_ — that's the whole point of expand/contract.

## Test the migration like code (`.claude/rules/testing.md`)

- **Run up → down → up** on a seeded copy in CI; assert data survives the round-trip.
- **Backfill correctness:** golden assertion on a known row set before/after.
- **Both-versions test:** old code against the post-Expand schema must still pass its suite.
- **Dry-run on a production-sized clone** to catch lock duration and timeout before prod feels it.

The migration is a proposal; the staging run on real-shaped data and the parity check are the gate.
For the decision record behind a non-trivial migration, write an ADR (`/adr`).

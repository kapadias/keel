---
name: concurrency-performance
description: Parallel, async or threaded code, shared mutable state, locks, or a hot path. Data races, deadlock, lost updates, idempotency, back-pressure, profile-before-optimize.
---

# Concurrency & Performance

Two disciplines that share one enemy: **guessing**. Concurrency bugs hide until the worst possible
interleaving under load; performance "improvements" are noise until measured. The rule for both is the
same — make it **correct and reproducible first**, then prove any change with evidence, not intuition.
A concurrency bug on money or state is auto-CRITICAL (`.claude/rules/safety.md`).

## Concurrency correctness — the failure modes

Assume the scheduler is adversarial: any interleaving that _can_ happen _will_, at scale, on the
unlucky request. Reason about what two threads do **between** your operations.

- **Data race** — two threads touch the same memory, ≥1 writes, no synchronization. Behavior is
  undefined, not just "sometimes wrong." Fix: a lock, an atomic, or — better — **don't share** (give
  each worker its own state; communicate by passing messages/immutables, not by sharing memory).
- **Lost update** — read-modify-write without atomicity: two requests read balance 100, each add 10,
  each write 110; one +10 vanishes. Fix: atomic compare-and-set, `UPDATE ... SET x = x + 10` in the
  DB, optimistic locking with a version column, or a serializable transaction. **Never** read-then-
  write a shared counter in app code and hope.
- **Deadlock** — two locks taken in opposite orders; each thread holds one and waits for the other,
  forever. Fix: a **global lock-ordering** (always acquire A before B), lock timeouts that fail closed,
  or reduce to a single lock / lock-free structure. Hold locks for the **shortest** span; never call
  out (I/O, another service, a callback) while holding one.
- **Check-then-act (TOCTOU)** — `if not exists: create` races into a duplicate; `if has_budget:
spend` races into an overspend. The check and the act must be **one atomic operation** (unique
  constraint, conditional write, `INSERT ... ON CONFLICT`), not two steps with a gap.

## Idempotency & the "exactly-once" illusion

**Exactly-once delivery does not exist** across a network — the ack can be lost after the work is done,
so the sender retries. You get _at-least-once_; you _engineer_ effectively-once by making the operation
**idempotent**: a stable key the receiver records, so a replay returns the original result instead of
acting again (`.claude/rules/safety.md`, `.claude/skills/api-design`). Every queue consumer, webhook
handler, and retried job must dedupe on a stable key. Assume **every message is delivered twice and
out of order**; if that corrupts state, the design is wrong, not the network.

## Performance method — measure, don't guess

> "Premature optimization is the root of all evil." — Knuth. Its corollary: optimization _without a
> profile_ is just guessing dressed up as work.

1. **Set a target.** "p99 < 200ms," "handle 5k rps." Without a number you can't know when to stop —
   you'll waste effort gold-plating a path that was already fast enough.
2. **Profile under realistic load** to find the _actual_ bottleneck. It is almost never where you
   think — and the 80/20 holds: one hot spot usually dominates. Optimizing anything else is wasted
   motion that adds complexity for no win.
3. **Fix the biggest cost first, re-measure.** Stop when you hit the target. Each change re-profiled —
   "optimizations" routinely make things slower.

## Big-O vs constant factors — know which regime you're in

- **Algorithmic (big-O) first when N grows:** an accidental O(n²) (a nested loop, a lookup in a list
  instead of a set/map, an **N+1 query** in a loop) is the most common real-world killer. A hash
  lookup vs a linear scan dwarfs any micro-tuning. Fix the complexity before touching constants.
- **Constant factors when N is bounded and the path is hot:** allocations in a tight loop, serialize/
  deserialize overhead, a syscall per item instead of a batch, cache misses. Here micro matters — but
  only after the algorithm is right. Don't hand-vectorize an O(n²).
- **The cheapest win is usually doing less work:** batch the N+1 into one query, cache a pure result,
  precompute, or page instead of loading everything. Less work beats faster work.

## Back-pressure & bounded queues — fail closed under overload

An **unbounded queue is an outage with a delay** — under load it grows until memory dies, taking
latency with it on the way down. Every buffer, pool, and in-flight set has a **bounded size**.

- When a bound is hit, apply back-pressure: **block the producer, shed load, or reject with a retry
  signal** — never silently grow. A rejected request is recoverable; an OOM-killed process is not
  (fail closed, `.claude/rules/safety.md`).
- **Bound concurrency** (worker pool / semaphore) and set **timeouts on every wait** — a wait with no
  timeout is a latent deadlock. Use a **circuit breaker** on a failing dependency so a slow downstream
  doesn't pin every worker and cascade the failure upstream.

## Benchmark discipline — a number you can trust or not at all

A benchmark without rigor lies confidently and sends you optimizing noise.

- **Warm up** before measuring (JIT, caches, connection pools) — discard the cold runs.
- **Report the distribution, not one number:** median + p99 + variance over many iterations. A single
  run is anecdote. If the variance is wide, the result is "no signal," not the best run you saw.
- **Control the environment:** fix input size, isolate the machine, pin or disable CPU frequency
  scaling; measure A and B back-to-back under the same conditions. A laptop on battery is not a bench.
- **Guard against regressions:** check the metric in CI with a tolerance band so a 2× slowdown fails
  the build instead of shipping silently (`.claude/rules/testing.md`).
- **Measure the realistic workload**, not a synthetic best case that lives entirely in L1 cache.

## Test concurrency deterministically (`.claude/rules/testing.md`)

You can't unit-test a race by hoping it shows up. Make the failure reproducible: a **property test**
hammering the operation from many workers and asserting the invariant (no lost update, count conserved,
idempotent on replay); inject the interleaving where the runtime allows; assert the **conserved
quantity** (total balance unchanged across N concurrent transfers). Then run it many times — a race
that fails 1-in-1000 must run 10k times in CI, not once.

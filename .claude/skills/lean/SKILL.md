---
name: lean
description: Sizing a solution before code: the seven-rung ladder (YAGNI, codebase, stdlib, native, installed dep, one line, minimum code), the never-simplify list, debt: markers.
---

# Lean

Lazy means efficient, not careless — the goal is the smallest correct diff, never the least effort.
The ladder below runs **after** you have read the task and the code it touches, not instead of
reading it. Trace the real flow — who calls this, what already exists two files over, what the
runtime already gives you for free — then climb.

## The ladder

Stop at the first rung that holds; do not climb past it "just in case."

1. **YAGNI** — does this need to exist? Name the lazier alternative in one line first. Half of
   "needed" code is speculative.
2. Already in this **codebase**? Reuse it. Re-implementing something that lives a few files over is
   the single most common slop pattern — search before you write.
3. The **stdlib** does it? Use it. Tested, documented, free; a hand-rolled equivalent is a
   maintenance liability with no upside.
4. A **native** platform feature covers it? Use it — `<input type="date">` over a date-picker
   dependency, a database `UNIQUE` constraint over app-level checks. The platform ships more than
   most reach for.
5. An already-**installed** dependency solves it? Use it. Never add a new dependency for what a few
   lines, or something already in the lockfile, already does.
6. Can it be **one line**? Make it one line — a comprehension or built-in beats a helper function
   that exists only to wrap it.
7. Only then: the **minimum code** that works — no speculative parameters, no config for a value
   that never changes, no layer for a future nobody asked for.

Two rungs both hold? Take the higher one — it is closer to "does not exist."

## Rules

- No interface with a single implementation, no factory for one product, no config knob for a value
  that never changes, no scaffolding "for later."
- Question a complex request in the same response, don't silently comply: "Did X; Y already covers
  the need. Want the full version? Say so."
- Two same-size stdlib options: take the one correct on the edge case, not the shorter one.
- The smallest change in the wrong place is still a second bug — lean is about size, not about
  dodging the real fix.

## Never simplified away

Not corners to cut, ever: validation at a trust boundary, error handling that prevents data loss,
security, accessibility, and anything the requester explicitly asked for. Keel's own gates are not
negotiable either: TDD with golden and property tests on the critical surface
(`.claude/rules/testing.md`), the machine-checked review verdict, and the five-mirror sync
(`.claude/rules/sync.md`). **The ladder governs solution size, never the loop.**

## The debt: marker

Mark a deliberate shortcut so it stays visible instead of becoming permanent by accident:
`debt: <ceiling>, <upgrade trigger>` — a comma separates what you accepted from the condition that
should make someone revisit it.

```
# debt: global lock, per-account locks if throughput matters
```

Both halves must be non-empty; a marker with no trigger after the comma is unfinished debt, not a
note. Gate: `scripts/check-debt.sh`. Default scans the tree and exits 1 if any marker lacks a
trigger. `--range <git-range>` scans only lines added in that diff — what `/review` runs, so a PR is
gated on debt it introduced, not on debt already in the tree. `--ledger` prints the grouped ledger
instead of gating — what `/sync` runs to check for drift. Usage error, or `--range` outside a git
repo, exits 2.

## Review tags

Format: `L<line>: <tag> <what>. <replacement>.` Tags: `delete:` — adds nothing, remove it;
`stdlib:` — a standard-library call replaces a hand-rolled block; `native:` — a platform feature
replaces custom logic or a dependency; `yagni:` — built for a need that does not exist yet;
`shrink:` — same behavior, fewer lines.

```
L42: stdlib:  27-line email validator class. `"@" in email` (or the stdlib's own check).
L58: native:  date-formatting library pulled in for one call. `Intl.DateTimeFormat`.
L71: yagni:   `AbstractRepository` with exactly one implementation. Inline it.
L90: delete:  retry wrapper around an idempotent local call that cannot fail transiently. Nothing.
L15: shrink:  manual loop building a dict from two lists. `dict(zip(keys, values))`.
```

Close with `net: -<N> lines possible.` when findings exist, or `Lean already. Ship.` when none do.
These findings carry `category: simplicity` and are **MEDIUM at most** — size never outranks
correctness or security.

## You think you need X → the platform has Y

| You think you need         | The platform has                     |
| -------------------------- | ------------------------------------ |
| Date picker library        | `<input type="date">`                |
| Deep-clone library         | `structuredClone`                    |
| UUID library               | `crypto.randomUUID()`                |
| `mkdirp`                   | `fs.mkdirSync(p, {recursive: true})` |
| `pytz`                     | `zoneinfo`                           |
| `requests` for one GET     | `urllib.request`                     |
| App-level uniqueness check | a `UNIQUE` constraint                |
| Pagination logic in code   | `LIMIT/OFFSET`                       |
| JS animation library       | a CSS transition                     |
| Modal dialog library       | `<dialog>`                           |
| lodash `debounce`          | a 5-line closure                     |
| `moment` for one format    | `Intl.DateTimeFormat`                |
| Hand-rolled deep-equal     | the test framework's own assertion   |
| Manual env-var loader      | the platform's built-in env access   |

## Output

Lead with the code, not the reasoning. What you deliberately skipped, and the trigger to add it
later, goes under **Remaining risk** in Keel's four-line report — never its own heading.

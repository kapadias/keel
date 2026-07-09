---
name: fast-lane
description: Apply when a change might qualify for the bounded fast lane — a trivial, reversible fix (roughly ≤15 changed lines, ≤3 files, no new dependencies, off the critical surface). Use when /fix runs, when deciding whether a small change needs the full loop, or when tuning fast-lane budgets for a repo.
---

# Fast lane — proportionality with a deterministic fence

The full loop (Research → Plan → TDD → Implement → Review → Verify → Ship → Sync) is the default
for a reason: it is where mistakes get caught. But a one-character typo fix and a schema migration
are not the same risk, and forcing both through the identical eight stages teaches people to bypass
the loop instead of trusting it. This is the **autonomy dial**: adjustable process depth, with the
adjustment made by a **script**, never by self-assessment. An agent that could argue its own change
into the fast lane would put the fox in charge of the henhouse — so eligibility is decided by
`scripts/check-trivial.sh`, which fails closed.

## Eligibility — the script decides

`bash .claude/skills/fast-lane/scripts/check-trivial.sh [base]` exits 0 **only if all hold**:

- **≤ 15 changed lines across ≤ 3 files** (added + deleted, vs the merge-base with `develop` by
  default). Test/fixture paths and `docs/STATUS.md` do not count against the budget — a fast-lane
  fix should be _mostly test_.
- **No dependency manifest or lockfile touched** — a new dependency is never trivial
  (supply-chain skill).
- **No critical-surface path touched**: `.claude/hooks/**`, `.claude/settings.json`,
  `.claude/skills/*/scripts/**`, `.github/workflows/**`, `**/migrations/**`. Extend per-repo via
  `KEEL_CRITICAL_PATHS` (colon-separated globs) — anything touching money, auth, persistence, or
  irreversible actions belongs on it.
- **No ambiguity**: not-a-repo, unresolvable base, or a binary change all exit 1. When
  classification is uncertain, the full loop applies — fail closed, per `rules/safety.md`.

The budgets are constants at the top of the script. Raising them is an explicit, reviewable act.

## What the fast lane skips — and what it never skips

| Skipped (proportionality)       | Never skipped (non-negotiable)                   |
| ------------------------------- | ------------------------------------------------ |
| The written plan (`/plan`)      | The failing-test-first rule (`rules/testing.md`) |
| Orchestrator fan-out            | The full local test gate                         |
| Two-reviewer parallel `/review` | Every hook (branch, secret, DoD)                 |
| ADR ceremony                    | The machine review verdict (`check-review.sh`)   |
|                                 | The one-line `docs/STATUS.md` entry              |

A single `code-reviewer` pass replaces the two-reviewer fan-out; its JSON verdict still goes
through `check-review.sh` with the identical severity gate. Behavior changes still pin a
regression test first (RED → GREEN); only docs/comment-only diffs — which have no behavior to
pin — skip it.

## If the script says no

Route through the full loop (`/plan` → `/tdd` → `/review` → `/ship`). Do not argue with the
classifier, shrink a change artificially to sneak under the budget, or split one logical change
into several "trivial" pushes — salami-slicing past a gate is a bypass, and the reviewer is told
to flag it.

# Rule: The Development Loop

The stages of the loop ([00-core.md](./00-core.md)), and what each one owes. Speed comes from doing
each stage well once, not from skipping the ones that catch mistakes.

**Proportionality — classify before you loop.** A trivial, reversible fix (≤15 lines, ≤3 files, no
new deps, off the critical surface — `check-trivial.sh` decides, fail-closed) may take the bounded
fast lane (`/fix`): regression test → gate → single machine-checked reviewer → ship. Everything else
takes the full loop below; when in doubt, the full loop (see the `fast-lane` skill).

## 0. Research & Reuse — before writing new code

Do not hand-roll what a battle-tested library already does correctly. Reinventing a parser, a date
library, an auth flow, or a crypto primitive is a correctness and security risk, not a flex.

1. **Search the codebase first.** Find the existing pattern, helper, or abstraction and match it. A
   change that looks like the code around it is easier to review and harder to get wrong.
2. **Search the ecosystem second.** Prefer a maintained, widely-used library over net-new code when it
   covers ≥80% of the need. Confirm exact API behavior against current docs, not memory.
3. **Capture non-obvious findings** as an ADR (`/adr`) or a note in `docs/`.

## 1. Plan

Restate the requirement in your own words, surface risks and unknowns, and decompose into reviewable
steps. **State the assumptions you are coding under.** If the request admits more than one reasonable
interpretation, present them and ask — never pick silently; push back when the requested approach
looks wrong, and **stop when confused**: "this seems off" beats plausible-looking wrong code. For
anything spanning multiple modules, write the plan down before coding (`/plan`). Name what could
break and how you will know. A plan that fits in your head is fine; a plan that doesn't must be on
disk.

## 2. TDD — RED → GREEN → REFACTOR

Tests come first — the cycle and the full policy are in [testing.md](./testing.md). The stage gate:
**a test that would have failed before this change exists, and you watched it fail.**

## 3. Implement

Follow [engineering.md](./engineering.md): typed, small, pure where it matters, no secrets, no silent
failures. Make the change look like it belongs in the file.

## 4. Review

Run `/review` before merge. Address every **CRITICAL** and **HIGH** finding; fix **MEDIUM** when
feasible. Changes that touch auth, data, money, or anything outward-facing also get a security pass.

## 5. Verify

Run the project's gate — typically lint + type-check + tests + coverage. A green local gate is
required, and **observed**, never inferred.

## 6. Commit & PR → Sync

Branch, commit, PR, and the five mirrors: [00-core.md](./00-core.md),
[git-workflow.md](./git-workflow.md), [sync.md](./sync.md).

**Report every completed unit in four lines** (mirrored by the PR template): **Assumptions** (what
you took as given), **Changed** (files/behavior), **Verified** (the gate you ran and its _observed_
result — never inferred), **Remaining risk** (what is not covered).

# Rule: The Development Loop

Every change moves through these stages **in order**. Do not skip stages. Speed comes from doing each
stage well once, not from skipping the ones that catch mistakes.

```
Research & Reuse → Plan → TDD (RED → GREEN → REFACTOR) → Implement → Review → Verify → Commit & PR → Sync
```

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

Tests come first. See [testing.md](./testing.md) for the full policy.

- **RED:** write the failing test that pins the desired behavior. No production logic lands without a
  test that would have failed before it.
- **GREEN:** the minimal implementation that passes.
- **REFACTOR:** clean it up with the tests green as your safety net.

## 3. Implement

Follow [engineering.md](./engineering.md): typed, small, pure where it matters, no secrets, no silent
failures. Make the change look like it belongs in the file.

## 4. Review

Run `/review` before merge. Address every **CRITICAL** and **HIGH** finding; fix **MEDIUM** when
feasible. Changes that touch auth, data, money, or anything outward-facing also get a security pass.

## 5. Verify

Run the project's gate — typically lint + type-check + tests + coverage. A green local gate is
required. **Never proceed with failing tests** (see [testing.md](./testing.md)).

## 6. Commit & PR → Sync

Feature branch, conventional commits, PR to `develop` (see [git-workflow.md](./git-workflow.md)). Then
close the loop: the work is not done until the **five mirrors** agree (see [sync.md](./sync.md)).

**Report every completed unit in four lines** (mirrored by the PR template): **Assumptions** (what
you took as given), **Changed** (files/behavior), **Verified** (the gate you ran and its _observed_
result — never inferred), **Remaining risk** (what is not covered).

## Routing

| Work type                   | Agent                                 | Command                      |
| --------------------------- | ------------------------------------- | ---------------------------- |
| Cross-cutting / multi-step  | `orchestrator`                        | —                            |
| Plan a change               | —                                     | `/plan`                      |
| Build it test-first         | `test-engineer` + `implementer`       | `/tdd`                       |
| Find code / "where is…"     | `explorer`                            | —                            |
| Diagnose a failure          | `debugger`                            | `/debug`                     |
| Review before merge         | `code-reviewer` + `security-reviewer` | `/review`                    |
| Run the gate / ship         | —                                     | `/test` · `/ship`            |
| Decision / task / reconcile | —                                     | `/adr` · `/intake` · `/sync` |

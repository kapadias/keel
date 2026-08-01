# Rule: Testing

Tests are the deterministic gate that decides whether a change is real. A failing test is a stop, never
a footnote. The LLM proposes a change; **the test suite decides** whether it is correct.

## TDD cycle

Write tests first. **RED** (a failing test pins the behavior) → **GREEN** (minimal code passes) →
**REFACTOR** (clean up with tests green). No production logic lands without a test that would have
failed before it. This is not ceremony — it is how you know the code does what you think.

## Two kinds of test, both required on the critical surface

- **Golden** — assert against a **known, hand-verifiable value**, not "it ran without error": a
  worked example you computed by hand, a fixed input → fixed output pair, a published result. Pin
  exact values (explicit tolerance for floats). Cross-check against a battle-tested library rather
  than trusting your implementation as its own oracle.
- **Property** — assert invariants over generated inputs, not just the cases you thought of:
  round-trips, idempotence, declared bounds, order independence where the contract promises it.

Worked examples and per-language templates: the `tdd-workflow` skill, preloaded into `test-engineer`.

## Coverage gate

Set a coverage floor in CI and **fail the build below it** — line and branch. Hold the highest bar on
the **survival-critical surface**: anything touching money, auth, data integrity, persistence, or
irreversible/outward-facing actions. New code in those areas requires both a golden and a property test
before merge. The rest aims high; the critical surface is a hard gate.

## Testing agents and LLM-driven components

Components that consume LLM or external output are tested as **adversaries**, not just happy paths:

- **Schema & bounds rejection:** malformed, out-of-range, or out-of-schema input is rejected
  deterministically — never clamped-and-passed silently downstream.
- **Graceful degradation:** with a dependency dead, slow, or returning garbage, the system fails
  **closed** (safe/defensive default), never open.

## Discipline

- **Deterministic tests only:** seed RNG, inject the clock, no real network in unit tests (gate
  anything needing live creds behind a marker/tag and skip it by default).
- **Never mark a task done — in the tracker, in `STATUS.md`, or in a PR — with failing tests.**
- A flaky test is a broken test. Fix it or quarantine it explicitly; never normalize red.

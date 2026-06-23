---
name: tdd-workflow
description: Apply when writing or changing code under test-driven development — starting a RED→GREEN→REFACTOR cycle, choosing between golden and property tests, making untestable code testable, or deciding where to spend coverage. Use when the loop reaches the TDD stage or `/tdd` is invoked.
---

# TDD Workflow

The test is the specification. You write it first because a test written after the code only
proves the code does what it does — not what it should. **The LLM proposes; the test decides.**

## The Cycle: RED → GREEN → REFACTOR

| Phase | Goal | Rule |
|---|---|---|
| **RED** | Write one failing test that pins the next increment of behavior | Run it. Watch it fail. Confirm it fails *for the stated reason*, not a typo or import error. |
| **GREEN** | Write the minimum code to pass | No extra abstraction, no speculative cases. Fastest honest path to green. |
| **REFACTOR** | Improve structure with tests green | Behavior unchanged; tests unchanged. See `refactoring`. |

One behavior per cycle. If a test needs three new code paths to pass, it is too big — split it.
Never write production logic that no failing test demanded.

## What makes a good failing test

- **Fails for the right reason.** A test that errors on setup is not RED — it is broken. The
  assertion, not the scaffolding, must be what fails.
- **Pins behavior, not implementation.** Assert on observable outputs and contracts. Tests coupled
  to private internals break on every refactor and rot.
- **Minimal and named for intent.** One logical assertion. The test name states the rule:
  `rejects_withdrawal_exceeding_balance`, not `test_withdraw_2`.
- **Deterministic.** Same inputs, same result, every run. Seed RNG, inject the clock, no network.

## Golden tests — exact oracle values

Assert against a **hand-verifiable known answer**, cross-checked against a trusted library where one
exists. Use for math, encoders, money, and any pure transform with a knowable correct output.

```python
# golden: value computed independently and pinned with explicit tolerance
def test_compound_interest_golden():
    assert compound(principal=1000, rate=0.05, years=3) == approx(1157.625, abs=1e-3)
```

Pin the exact number. State *where it came from* (a reference impl, a textbook, a spreadsheet). A
golden test with an oracle the author guessed is worthless.

## Property tests — invariants over generated inputs

Assert a rule that must hold for *all* valid inputs; let the framework hunt counterexamples.
The high-value invariant families:

- **Round-trip:** `decode(encode(x)) == x`
- **Idempotence:** `f(f(x)) == f(x)` (normalizers, retries, upserts)
- **Bounds:** output stays within declared limits for any input (sizing never exceeds the cap)
- **Order-independence:** result invariant to input ordering (sums, set operations)

```python
# property: parsing then serializing is identity for any valid record
@given(records())
def test_serialize_roundtrip(rec):
    assert parse(serialize(rec)) == rec
```

Golden tests catch *wrong*; property tests catch *the case you didn't think of*. Survival-critical
code wants both.

## Make the untestable testable

Untestable code is a design smell, not a reason to skip the test.

- **Inject the clock.** Never call `now()` inside logic; pass a time value or a clock. Then "expires
  after 30 days" is a pure assertion.
- **Inject the RNG/seed.** Randomness in a decision path takes an explicit seed, never the global.
- **Isolate I/O at the edges.** Keep the core pure (data in → data out); push network, disk, and
  clock to a thin shell. You test the core directly and mock only the shell.

## Where to spend coverage

Coverage is a budget — aim it at the **survival-critical surface**: money, auth, data integrity,
persistence, and anything **irreversible**. There, demand golden + property tests and high branch
coverage. Glue and display code aim high but are not the gate. Coverage percent is a floor, never a
goal — 100% over vacuous asserts proves nothing.

## Anti-patterns

- **Test written after** — it documents behavior instead of specifying it; you lose the RED signal.
- **Vacuous / self-referential asserts** — `assert result == result`, asserting a mock was called
  with what you just told it. Reassert nothing.
- **Mock everything** — a test where every collaborator is faked tests the mocks. Mock the edge;
  exercise the real core.
- **Flaky tests** — time, ordering, or network leaking in. Quarantine and fix; a flaky test trains
  the team to ignore red. A red suite is a stop, not a footnote.

See `.claude/rules/testing.md` for the coverage gate and marker policy; route work through the
`test-engineer` agent and `/test`.

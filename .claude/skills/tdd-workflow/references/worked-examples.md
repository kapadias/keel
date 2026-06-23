# Worked examples — golden & property tests (Python)

Longer, copy-ready examples in **Python (pytest + Hypothesis)**. The principles are language-agnostic;
for ready-to-copy skeletons in TypeScript (vitest + fast-check) and Go (testing + rapid) see the
[`../templates/`](../templates) directory. The short version of the philosophy lives in the
SKILL body; this file is the depth.

## Golden tests — exact, hand-verifiable oracles

A golden test asserts against a **known answer you obtained independently** — computed by hand, taken
from a textbook or spec, or produced by a battle-tested reference library. It catches _wrong_. The
oracle's provenance is the whole point: a golden test whose expected value the author merely guessed
proves nothing.

```python
from pytest import approx


def test_compound_interest_golden():
    # Oracle: A = P(1 + r)^n = 1000 * 1.05**3 = 1157.625 (computed independently; see ADR-014).
    # Pin the exact value with an explicit tolerance — never assert float equality bare.
    assert compound(principal=1000, rate=0.05, years=3) == approx(1157.625, abs=1e-3)
```

Pin the number **and state where it came from**. For a parser/formatter, pin a fixed input → fixed
output pair:

```python
def test_iso8601_formats_utc_golden():
    # Oracle: hand-verified against RFC 3339 §5.8 example.
    from datetime import datetime, timezone
    ts = datetime(1985, 4, 12, 23, 20, 50, tzinfo=timezone.utc)
    assert format_iso8601(ts) == "1985-04-12T23:20:50Z"
```

Cross-check against a trusted library where one exists, rather than trusting your own implementation as
its own oracle:

```python
import base64


def test_base64_matches_stdlib_oracle():
    # Don't trust our encoder against itself; pin it to the stdlib's battle-tested result.
    payload = b"keel:golden-oracle"
    assert my_b64encode(payload) == base64.b64encode(payload).decode()
```

## Property tests — invariants over generated inputs

A property test states a rule that must hold for **all** valid inputs and lets the framework hunt
counterexamples — it catches _the case you didn't think of_. The four high-value invariant families:

### Round-trip — `decode(encode(x)) == x`

```python
from hypothesis import given
from hypothesis import strategies as st


@given(st.builds(Record, id=st.integers(min_value=0), name=st.text()))
def test_serialize_roundtrip(rec):
    assert parse(serialize(rec)) == rec
```

### Idempotence — `f(f(x)) == f(x)`

For normalizers, retries, upserts — applying twice equals applying once.

```python
@given(st.text())
def test_normalize_is_idempotent(s):
    once = normalize_whitespace(s)
    assert normalize_whitespace(once) == once
```

### Bounds & conservation — output stays within declared limits

```python
@given(st.lists(st.integers(min_value=0, max_value=10_000)), st.integers(min_value=1, max_value=512))
def test_chunks_never_exceed_cap(items, cap):
    for chunk in chunk_by_size(items, cap):
        assert sum(chunk) <= cap            # the sizing contract holds for ANY valid input
    assert sum(len(c) for c in chunk_by_size(items, cap)) == len(items)  # nothing lost or duplicated
```

### Order-independence — result invariant to input ordering

```python
import random


@given(st.lists(st.integers()))
def test_sum_is_order_independent(xs):
    shuffled = xs[:]
    random.Random(0).shuffle(shuffled)     # seeded — deterministic test
    assert total(xs) == total(shuffled)
```

## Why both, on the critical surface

Golden tests anchor correctness to a _specific_ known answer; property tests explore the _space_ of
inputs for the case you missed. On the survival-critical surface (money, auth, data integrity,
persistence, anything irreversible) demand **both** before merge, plus high branch coverage. See
`.claude/rules/testing.md` for the coverage gate and the marker policy for tests needing live creds.

## Determinism is non-negotiable

Seed every RNG, inject every clock, allow no real network in a unit test. A property test that flakes
is worse than none — it trains the team to re-run until green and ignore real counterexamples. If
Hypothesis surfaces a failing example, it has found a real bug: pin that example as a regression test
(`@example(...)`) and fix the code, never loosen the property.

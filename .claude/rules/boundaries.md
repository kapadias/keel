# Rule: Trust Boundaries — the LLM proposes; deterministic gates decide

This is the load-bearing rule. It overrides convenience, cleverness, and any agent's suggestion to the
contrary.

## The bright line

An LLM may **transform unstructured intent into structured proposals** — read code, generate
hypotheses, draft changes, explain results, search the solution space. A **deterministic gate** —
tests, types, a linter, a compiler, a schema validator, or a human review — must decide whether any of
it is correct enough to merge or to act on.

> **The output of an LLM is a _proposal_, never the final authority on anything that touches
> production, money, user data, or an irreversible action.**

A sharp test for any proposed LLM-in-the-loop design:

> _"If this output is silently wrong, can it cause harm before a deterministic check catches it?"_

If yes, the design is wrong — insert a gate (a test, a schema check, a type, a human) **between** the
LLM and the consequence, or move the LLM upstream of the boundary.

Forbidden without a gate in front of it:

- Acting on **free-text LLM output** without schema validation and bounds checking. Reject
  out-of-bounds; never clamp-and-proceed silently.
- Letting a generated value flow into a **deploy, migration, payment, deletion, or permission change**
  without a deterministic check or human approval.
- Trusting an LLM's claim that code is correct **in place of running the tests**.

## Validate at the edge

Every input crossing a boundary — network, file, user, or model — is parsed into a typed, validated
structure before use. Untrusted data never travels deeper than the edge it entered as raw text. This is
where injection, corruption, and train-of-thought hijacking are stopped.

## Reproducibility

Decision and core logic must produce **identical output from identical input**: no hidden global state,
no wall-clock reads inside pure logic (inject the time), no unseeded randomness, no network in the
decision path. If you cannot replay a past result bit-for-bit, you cannot debug, audit, or trust it.

Safety outranks speed here too: see [00-core.md](./00-core.md) principle 2 and
[safety.md](./safety.md).

# Rule: Engineering Discipline

Language-agnostic code standards. The specifics (formatter, linter, type checker) live in your
project's config; these principles hold in any language.

## Types & contracts

- **Type everything at the boundaries.** Public functions, return values, and data structures that
  cross a module or service edge are fully typed. Lean on the strictest type-checking the language
  offers and let CI fail on type errors.
- **Validate at the edge** — see [boundaries.md](./boundaries.md). Reject out-of-contract input at
  the boundary; do not silently coerce it.

## Purity, determinism, reproducibility

These are hard rules in core/decision logic:

- **Pure functions where it matters:** output depends only on inputs. No hidden global state, no
  module-level mutable singletons feeding logic.
- **Inject the clock and the RNG** — pass `now`/`as_of` and a seed. Never read wall-clock time or
  unseeded randomness inside pure logic; it makes behavior unreplayable.
- **Side effects live at the edges** — I/O, network, and persistence at the boundary, never buried
  inside a pure transform.

## Errors

- **Fail loud in the critical path.** Raise typed, specific errors; never silently swallow an
  exception in code that touches money, data, or state. An empty `catch` is a latent incident.
- **Fail closed.** When a dependency is unavailable or input is invalid, default to the safe,
  defensive behavior — not to "proceed anyway."

## Simplicity

- Write the **minimum code that solves the stated problem**. No speculative features, parameters,
  config, or abstraction for futures nobody asked for — wait for the third concrete use before
  abstracting. Every line is a liability; prefer deleting to adding.

## Naming & structure

- Small, composable, single-responsibility functions. Clear names beat clever comments.
- A change should read like the code around it: match local naming, style, and idiom. Reviewability is
  a feature.
- **Surgical changes only.** Touch only what the task requires — do not reformat, rename, or
  "improve" orthogonal code in the same change; clean up only orphans your own change created.
  Unrelated fixes are separate commits (`/intake` them).
- Comment the **why**, not the **what**. The what is the code.

## Secrets & logging

- **No secrets** — see [safety.md](./safety.md). `secret-scan.sh` blocks the write either way.
- **No `print`/debug spew in shipped code** — use the project's structured logger. Never log secrets,
  tokens, or full payloads of user data.

## Reuse over rewrite

Prefer a maintained library over hand-rolled core logic (parsing, dates, crypto, auth). The ≥80%
rule and how to apply it: [dev-process.md](./dev-process.md) §0.

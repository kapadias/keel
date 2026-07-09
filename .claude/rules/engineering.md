# Rule: Engineering Discipline

Language-agnostic code standards. The specifics (formatter, linter, type checker) live in your
project's config; these principles hold in any language.

## Types & contracts

- **Type everything at the boundaries.** Public functions, return values, and data structures that
  cross a module or service edge are fully typed. Lean on the strictest type-checking the language
  offers and let CI fail on type errors.
- **Validate at the edge.** Every input from a network, file, user, or LLM is parsed into a typed,
  validated structure before use. Never trust unvalidated external data deeper than the boundary it
  entered. Reject out-of-contract input; do not silently coerce it.

## Purity, determinism, reproducibility

These are hard rules in core/decision logic:

- **Pure functions where it matters:** output depends only on inputs. No hidden global state, no
  module-level mutable singletons feeding logic.
- **No wall-clock or randomness in pure logic.** Inject the clock (pass `now`/`as_of`) and the RNG
  (pass a seed). This makes behavior testable, replayable, and reproducible bit-for-bit.
- **Side effects live at the edges** — I/O, network, and persistence at the boundary, never buried
  inside a pure transform.

## Errors

- **Fail loud in the critical path.** Raise typed, specific errors; never silently swallow an
  exception in code that touches money, data, or state. An empty `catch` is a latent incident.
- **Fail closed.** When a dependency is unavailable or input is invalid, default to the safe,
  defensive behavior — not to "proceed anyway."

## Simplicity

- Write the **minimum code that solves the stated problem**. No speculative features, parameters,
  config, or abstraction layers for futures nobody asked for — wait for the third concrete use
  before abstracting. Every line is a liability; prefer deleting to adding.

## Naming & structure

- Small, composable, single-responsibility functions. Clear names beat clever comments.
- A change should read like the code around it: match local naming, style, and idiom. Reviewability is
  a feature.
- **Surgical changes only.** Touch only what the task requires — do not reformat, rename, or
  "improve" orthogonal code in the same change; clean up only orphans your own change created.
  Unrelated fixes are separate commits (`/intake` them).
- Comment the **why**, not the **what**. The what is the code.

## Secrets & logging

- **No secrets in code, logs, traces, or prompts.** Credentials live in a secret manager or
  git-ignored `.env` (read-denied in `.claude/settings.json`), never committed.
- **No `print`/debug spew in shipped code** — use the project's structured logger. Never log secrets,
  tokens, or full payloads of user data.

## Reuse over rewrite

Prefer a maintained library over hand-rolled core logic (parsing, dates, crypto, auth). If a library
covers ≥80% of the need, wrap it rather than rebuild it. See [dev-process.md](./dev-process.md).

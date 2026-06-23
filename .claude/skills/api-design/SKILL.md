---
name: api-design
description: Apply when designing or changing an interface — a library API, a service endpoint, or a module boundary. Use when defining contracts (inputs, outputs, errors), validating untrusted input, planning idempotency and versioning, or shaping a public surface.
---

# API Design

An API is a contract and a promise of stability. Design the boundary so callers fall into the pit of
success — and so **illegal states are unrepresentable** rather than merely discouraged.

## Contracts: types in, types out, errors in between

The contract is the _whole_ signature: the accepted input types, the returned type, **and the errors
the caller must handle.** Errors are part of the contract, not an afterthought — enumerate them.

- **Types carry intent.** `Money(currency, minor_units)` beats a bare `float`; `UserId` beats a
  `str`. The type system rejects whole classes of misuse for free.
- **Make illegal states unrepresentable.** Prefer a closed set (`enum`/union) over a free string;
  prefer a type that _can't_ hold a bad combination over runtime validation of one that can.
- **Minimize surface area.** Every public symbol is a forever-promise. Expose the smallest set that
  serves the use case; keep the rest internal. You can add later; you can't quietly remove.

## Validate untrusted input at the edge

Everything from outside — request bodies, query params, file contents, another service — is hostile
until checked. **Validate at the boundary**, convert to a trusted internal type, and let the core
assume validity. Reject out-of-range; never clamp-and-proceed silently. (`.claude/rules/boundaries.md`)

```text
# edge: parse-and-validate into a trusted type, or reject
def create_order(raw):
    qty = require_int(raw["qty"], min=1, max=10_000)     # reject, don't clamp
    sku = require_known_sku(raw["sku"])
    return place(Order(sku=sku, qty=qty))                # core trusts the type
```

## Errors: typed, meaningful, never swallowed

Return errors that tell the caller **what to do**: distinguish _invalid input_ (caller's fault, don't
retry) from _transient failure_ (retry with backoff) from _conflict_ (re-read and reconcile). Use
typed errors or a result type — never a bare boolean or a `null` that erases the reason. **Never
swallow an error** to keep a signature clean; an unhandled failure that vanishes is the worst outcome.

## Idempotency and retry safety for mutations

Networks retry. A mutation that runs twice must not act twice.

- **Stable idempotency keys.** The caller supplies a key; the server records it and returns the
  original result on replay. Same key + same request → one effect. (`.claude/rules/safety.md`)
- **Reads are safe; writes are guarded.** Design `GET`-shaped operations to be side-effect-free so
  retries are free. For writes, define what a duplicate means _before_ shipping.

## Consistency, least surprise, and bounded collections

Like things look alike: consistent naming, argument order, pagination shape, and error format across
the whole surface. **Name for intent** — `cancel_order`, not `set_status`; `expires_at`, not `flag`.
Any endpoint returning a list **must** bound its output — there is no "return all." Page with a stable
cursor (not a fragile offset), cap page size with a server-side maximum, and document the default.

## Versioning — additive is safe, breaking needs a version

**Additive changes are safe** (new optional field, new endpoint); **breaking changes need a new
version** (removing/renaming a field, tightening a type, changing semantics). Default new fields so old
clients keep working; deprecate with a window and a migration path — never yank. Full policy — version
schemes, the deprecation sequence, sunset headers, and compatibility gates — in
[`references/versioning-and-deprecation.md`](references/versioning-and-deprecation.md).

## Design the contract first, then test it, then implement

```text
# bad: ambiguous in, lossy out, unbounded, untyped error
def transfer(a, b, amt) -> bool         # which way? what currency? false = ?

# good: intent in the types, errors enumerated, idempotent, bounded
def transfer(
    src: AccountId, dst: AccountId, amount: Money, idempotency_key: str,
) -> Result[Receipt, TransferError]     # InsufficientFunds | AccountFrozen | Duplicate
```

Write the **contract test against the boundary**, then implement behind it — the implementation is
replaceable; the contract is not. Copy-ready starting points in [`templates/`](templates):
[`contract.test.ts`](templates/contract.test.ts) (a request/response contract test asserting
validate-at-edge, typed errors, and idempotent retry) and
[`openapi-contract.stub.yaml`](templates/openapi-contract.stub.yaml) (an endpoint schema with typed
money, enumerated errors, a required idempotency key, and capped pagination).

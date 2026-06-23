# Versioning & deprecation — API depth

A published contract is owed stability. Callers you cannot see depend on today's behavior; a silent
breaking change is an outage you ship to them. This reference expands the SKILL's one-paragraph rule
into the full policy.

## Additive is safe; breaking needs a new version

The dividing line is whether an _existing, conforming_ client keeps working unchanged.

**Safe (additive) — ship without a version bump:**

- A new **optional** request field (with a default; absent means the old behavior).
- A new response field (clients must ignore unknown fields — design them to).
- A new endpoint, a new enum _value the client opted into_, a new optional query param.
- Relaxing a constraint (accepting input you previously rejected) — but see "widening" caveats below.

**Breaking — requires a new version (or a long deprecation window):**

- Removing or **renaming** a field, endpoint, or parameter.
- **Tightening** a type or constraint (narrower range, new required field, stricter regex).
- Changing the **semantics** of an existing field (same name, different meaning) — the most dangerous
  break, because it passes schema validation while silently corrupting behavior.
- Changing default values, error codes/shapes, pagination behavior, or sort order callers rely on.
- Making a previously optional field required.

> A new enum value can be breaking even though it "feels" additive: a client with an exhaustive
> `switch` over the old set now hits an unhandled case. Document that consumers must tolerate unknown
> enum values, or treat new values as a versioned change.

## How to version

Pick one scheme and apply it consistently across the whole surface:

- **URI path** — `/v1/orders`, `/v2/orders`. Most visible, easiest to route and cache, coarse-grained.
- **Header / media type** — `Accept: application/vnd.acme.v2+json`. Keeps URLs stable; harder to
  eyeball and to curl. Good for content negotiation.
- **Library / package SemVer** — for an SDK or module boundary: MAJOR for breaking, MINOR for additive,
  PATCH for fixes. The version _is_ the contract; bump MAJOR for anything in the breaking list above.

Keep the version coarse (per-API, not per-field). Run the old and new versions side by side during the
migration window; do not hot-swap semantics under a single version.

## Deprecation — a window and a migration path, never a yank

Deprecate; don't delete out from under callers. The disciplined sequence:

1. **Announce** in docs and the changelog; mark the field/endpoint deprecated in the schema/OpenAPI
   (`deprecated: true`) and in SDK types (`@deprecated`).
2. **Signal at runtime** — return a `Deprecation` and `Sunset` header (RFC 8594) and/or a warning in
   the response envelope, so integrators discover it without reading release notes.
3. **Provide the replacement and a migration note** — what to call instead, and how to map old → new.
   A deprecation with no migration path is just a threat.
4. **Set and honor a sunset date** with a window proportional to blast radius (weeks for an internal
   consumer; months-to-quarters for a public API). Measure remaining usage before removal.
5. **Remove** only after the window closes _and_ telemetry shows the old path is unused (or owners have
   been notified and signed off). Removal is the irreversible, outward-facing step — gate it like one
   (`.claude/rules/safety.md`).

## Defaults are part of the contract

Default new fields so old clients keep working. Changing a default is a behavior change even though the
signature is untouched — treat it as breaking. Document every default and where it is applied (server
vs client).

## Compatibility testing

Make compatibility a deterministic gate, not a hope:

- **Contract tests** run against the boundary (see [`../templates/`](../templates)); they fail when a
  field is removed, a type tightens, or an error shape changes.
- **Schema diffing** in CI (e.g. an OpenAPI/Proto breaking-change linter) flags a breaking edit before
  it merges — the LLM proposes the schema change; the diff gate decides (`.claude/rules/boundaries.md`).
- **Consumer-driven contracts** (e.g. Pact) let each consumer pin the slice of the contract it depends
  on, so the provider learns at build time what it cannot break.

---
name: supply-chain
description: Apply when adding or upgrading a dependency, or reviewing a lockfile change. Use when vetting a new package (the ≥80%-of-the-need rule), pinning versions, checking provenance/integrity, scanning for known vulns, spotting typosquats, or scoping CI tokens. Bundles scripts/dep-audit.sh.
---

# Supply Chain Security

Your dependencies run with your code's full privileges — in your CI, your build, and production. A
compromised package is a compromise of _you_. Most breaches in this space aren't exotic: a typosquat
someone installed, a postinstall script no one read, a known CVE that sat un-upgraded, or a CI token
with far too much scope. The discipline is **distrust by default and verify before adopting**
(`.claude/rules/boundaries.md`, `.claude/rules/safety.md`).

Run the bundled `scripts/dep-audit.sh` on any dependency or lockfile change — it auto-detects the
ecosystem and runs the right vuln scanner, failing on findings.

## Before you add it — vetting a new dependency

Adding a dependency is a permanent liability and a new entry in your attack surface. The bar is high.

1. **Do you need it at all?** The Keel rule: reuse a maintained library when it covers **≥80% of the
   need** — but a one-liner you can write and own beats pulling a transitive tree for a trivial
   helper (`left-pad`). For **parsing, dates, crypto, auth** — always the vetted library, never
   hand-rolled (`.claude/rules/dev-process.md`, `.claude/rules/engineering.md`).
2. **Is it healthy?** Recent commits, real maintainers (bus factor > 1), responsive security history,
   adoption you can verify. An abandoned package with a known CVE is a time bomb.
3. **What does it drag in?** Look at the **transitive** tree and the **install scripts**. A package
   with a `postinstall`/`preinstall` runs arbitrary code on every `install` — in CI, with your tokens.
   Read it. Prefer dependencies with few or no transitive deps and no install hooks.
4. **What can it reach?** A library that wants network/filesystem/child-process it has no business
   needing is a red flag. Least privilege applies to code you import, not just code you write.

Capture the _why_ of a non-obvious adoption in an ADR (`/adr`) — the next person will ask.

## Pinning & lockfiles — reproducible by construction

A build that resolves different bytes on different days is unauditable and un-reproducible
(`.claude/rules/boundaries.md`).

- **Commit the lockfile** (`package-lock.json`, `poetry.lock`, `Cargo.lock`, `go.sum`, `pnpm-lock`,
  `requirements.txt` with hashes). It is the source of truth for _exact_ resolved versions.
- **Install from the lock, frozen, in CI:** `npm ci` (not `npm install`), `poetry install --sync`,
  `pip install --require-hashes`, `go mod verify`, `cargo build --locked`. A CI that re-resolves can
  silently pull a new (or malicious) version — pin and freeze.
- **Pin exact versions** for apps; a floating `^`/`~`/`*` range means your next build is a gamble on
  whatever was published since. (Libraries publish ranges; _applications_ pin.)

## Provenance & integrity — verify the bytes are the ones you vetted

- **Hash-locked installs:** the lockfile records an integrity hash per package; the frozen install
  **verifies** it. Don't disable integrity checking to make an install pass — that's removing the gate.
- **Prefer signed/attested artifacts** where the ecosystem supports it (Sigstore/cosign, npm
  provenance, `go.sum`'s checksum DB). Provenance ties the artifact to its source build.
- **Pin CI actions/images by digest, not a moving tag.** `actions/checkout@<sha>` not `@v4`;
  `image@sha256:...` not `:latest`. A tag can be re-pointed at malicious code under you.

## Known-vuln scanning — automated and blocking

- Run the ecosystem scanner **in CI and fail the build on findings**: `npm audit`, `pip-audit`,
  `govulncheck`, `cargo audit` (the bundled `dep-audit.sh` picks the right one). A vuln report that
  doesn't block merge is a report nobody reads.
- **Triage, don't blanket-ignore.** Suppress a specific advisory only with a written reason and an
  expiry, never a global `--audit-level=none`. Fix-by-upgrade beats suppress.
- **Scan on a schedule, not just on change** — CVEs are disclosed against versions you already ship.
  A dependency safe at merge is vulnerable the day an advisory drops.

## Typosquatting & install-time attacks — the cheap, common exploit

- **Verify the exact name** before installing: `requets`, `python-dateutil` vs `python3-dateutil`,
  `crossenv` vs `cross-env`. A transposed letter installs an attacker's package that runs on install.
- **Watch for dependency confusion:** a public package shadowing your internal name. Scope/namespace
  internal packages and configure the registry to prefer your private source.
- **Audit the lockfile _diff_, not just `package.json`.** The danger hides in transitive resolutions
  and integrity-hash changes a top-level bump pulled in. A one-line manifest change can rewrite dozens
  of resolved packages — review them.

## Least-privilege CI tokens — assume the build can be compromised

CI is where supply-chain attacks cash out: it has your publish tokens, cloud creds, and secrets.

- **Scope tokens to the minimum** and prefer short-lived **OIDC** federation over long-lived static
  secrets. A read-only job gets a read-only token.
- **Don't expose secrets to PRs from forks**, and don't let untrusted PR code run in a context that
  can read them (the classic `pull_request_target` foot-gun).
- **Pin and minimize the actions/plugins your pipeline runs** — each is code with access to that
  token. Same vetting bar as a runtime dependency.

## Reproducible builds

Same source + same locked deps → **bit-identical artifact**. Pin the toolchain/base image by digest,
freeze deps from the lock, avoid embedding timestamps/absolute paths/build-host state. Reproducibility
is what lets you prove the artifact you're shipping is built from the source you reviewed — without it,
"it's the same code" is a hope, not a fact (`.claude/rules/boundaries.md`).

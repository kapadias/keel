---
name: security-review
description: Apply when a change touches authentication, authorization, secrets, money, user data, deserialization, file/URL/network handling, or anything outward-facing. Use when `/security-review` runs or the security-reviewer agent engages — a standalone threat-model pass beyond the correctness review.
---

# Security Review

Think like the attacker who wants your data, your money, or your compute — not like the author who
wants the feature to ship. The correctness reviewer asks "does it work?"; you ask **"how is it
abused?"** A finding that only says something "smells" is noise. **Show the exploit or downgrade the
severity.** Safety is lexicographically prior to speed (`.claude/rules/safety.md`).

## The exploit-sketch contract — non-negotiable

Every CRITICAL/HIGH finding carries a concrete **abuse path**: the input, the step, the consequence.
If you cannot sketch one, you have a hardening suggestion (MEDIUM at most), not a vulnerability.

> `api/files.py:42` — CRITICAL (path traversal): `open(base + request.path)` with no canonicalization.
> **Exploit:** `GET /files?path=../../../../etc/passwd` escapes `base` and reads arbitrary host files.
> **Fix:** resolve to an absolute real path and assert it is under `base` (`realpath`/`os.path.commonpath`); reject otherwise.

The sketch is what turns "looks risky" into a gate a deterministic check can be written against.

## Threat-model checklist — trace each from untrusted source to dangerous sink

Untrusted = anything you don't fully control: request bodies, params, headers, cookies, file uploads,
filenames, env on a shared host, **and any LLM output**. Walk each from where it enters to where it
acts.

- **Injection** — untrusted text reaching an interpreter: SQL, shell/`exec`, OS command, NoSQL,
  LDAP, template (SSTI), XSS into HTML, log injection. _Sink test:_ is the value ever concatenated
  into a query/command/markup instead of passed as a bound parameter / via `execve`-style arg arrays
  / context-aware escaped? Parameterize; never interpolate.
- **Broken authz / IDOR** — the request is _authenticated_ but the object isn't _authorized_.
  `GET /invoice/1043` returning another tenant's invoice because the handler loads by id without an
  owner predicate. _Test every object read/write:_ is there a `WHERE owner = current_user` (or
  equivalent policy check) **at the data layer**, not just a UI gate? Check function-level authz too
  (can a normal user call the admin endpoint?).
- **Secret leakage** — keys/tokens/PII in code, logs, traces, error responses, URLs (query strings
  get logged), stack traces returned to clients, or LLM prompts. Grep the diff for hardcoded
  credentials and for logging of whole request/response objects. (`.claude/rules/engineering.md`)
- **Unsafe deserialization** — `pickle`, Java/Ruby native deserialization, YAML `load` (vs
  `safe_load`), `eval`/`Function` on input. These are remote code execution, not data bugs. Untrusted
  bytes must hit only a schema-validated, type-restricted parser.
- **SSRF** — server fetches a user-supplied URL (webhooks, image proxies, "import from URL", PDF
  renderers). _Exploit:_ `http://169.254.169.254/latest/meta-data/` steals cloud credentials; internal
  hostnames reach private services. Deny by default: allowlist schemes/hosts, resolve then re-check
  the IP (block link-local/private/loopback), and disable redirects to new hosts.
- **Supply chain** — a new/changed dependency, a postinstall script, a lockfile delta. Hand to the
  `supply-chain` skill; do not eyeball-approve transitive trees.

Also sweep: **auth/session** (token validation, expiry, fixation, weak/missing CSRF on cookie auth),
**crypto** (no homemade crypto, no ECB, no static IV, constant-time compares for secrets/HMACs),
**SSRF's cousins** (open redirect, XXE via external entities), **mass assignment** (binding request
JSON straight onto a model exposes `is_admin`), and **rate-limiting** on auth/expensive endpoints.

## Severity rubric — inherits code-review, with a security lens

Same scale as the `code-review` skill so verdicts compose. Anchor on **blast radius × reachability**.

| Severity     | Security meaning                                                                                                                                                                              |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CRITICAL** | Remote exploit reaching prod data/money/RCE with a plausible path: injection, authz bypass/IDOR, deserialization RCE, SSRF to metadata, leaked live credential. Auto-block.                   |
| **HIGH**     | Real vuln gated by a precondition (needs a low-priv account, a specific config) — stored XSS, missing object authz on a sensitive write, secret in logs, CSRF on a state change. Block merge. |
| **MEDIUM**   | Defense-in-depth gap with no direct exploit shown — missing rate limit, weak header, overbroad token scope, verbose error. Fix when feasible.                                                 |
| **LOW**      | Hardening nicety — header polish, dependency a major behind with no known CVE. Optional.                                                                                                      |

Auto-CRITICAL with no debate: a working **injection**, an **authz bypass**, a **leaked live secret**,
or **untrusted bytes into a code-executing deserializer**. The verdict cannot be safe-to-merge until
each is closed or has a deterministic gate (validation/policy check) proven in front of it.

## Validate at the edge, fail closed

The two principles that close most of the above. **Parse untrusted input into a typed, bounded
structure at the boundary** and reject out-of-contract — never clamp-and-proceed
(`.claude/rules/boundaries.md`). On any ambiguity — auth check errored, allowlist lookup failed,
signature unverifiable — **deny**, don't proceed. A missed stop can be terminal; a false stop costs
a retry (`.claude/rules/safety.md`).

## Finding & verdict format — identical contract to code-review

One finding = **`path:line` + category + the exploit sketch + a concrete fix.** Close with a verdict
so the two reviews merge cleanly:

```
SECURITY VERDICT: CHANGES REQUIRED  (or: NO BLOCKING FINDINGS)
CRITICAL: <n>   HIGH: <n>   MEDIUM: <n>   LOW: <n>
- [CRITICAL] path:line — category — exploit in one line → fix
- [HIGH]     path:line — ...
```

Safe-to-merge once every CRITICAL and HIGH is closed. Prefer **few high-confidence findings with real
abuse paths** over a long speculative list — ten "could be hardened" notes bury the one RCE. The
deterministic gate decides, not the author's confidence. Route security-sensitive diffs through the
`security-reviewer` agent; pair with the `code-review` skill for the correctness pass.

---
description: Path-aware parallel review before merge — always a correctness review; adds a security review when the change touches auth, data, money, input handling, or anything outward-facing.
argument-hint: "[scope — paths/files; defaults to the current branch diff vs develop]"
---

Review: **$ARGUMENTS** (if empty, review the current branch's diff vs `develop`).

## Steps

1. **Scope and classify.** Get the changed files (`git diff develop...HEAD --name-only`, or the
   explicit `$ARGUMENTS`). Flag whether the change touches **auth, data, money, input handling,
   secrets, or anything outward-facing** (deploy, migration, external API).
2. **Launch reviewers in PARALLEL** (independent — do not serialize):
   - **Always:** `code-reviewer` — correctness, broken contracts, missing/weak tests, silent failures,
     reproducibility, style fit.
   - **If the change touches auth / data / money / input / secrets / outward-facing surfaces:** also
     `security-reviewer` — injection, secret leakage, broken authz, unsafe deserialization, supply
     chain.
3. **Synthesize.** Merge findings into one report, deduplicated, grouped by severity —
   **CRITICAL / HIGH / MEDIUM / LOW** — each with `path:line`, the issue, and a concrete fix. Any breach
   of a trust boundary, a safety gate, or "fail-closed" is automatically CRITICAL.
4. **Verdict.** State plainly whether this is safe to merge to `develop`: address all CRITICAL and HIGH
   before shipping; fix MEDIUM when feasible.

## Output

The consolidated, severity-grouped findings and the merge verdict. If any issues were fixed inline,
note them. Update the tracked issue with the outcome.

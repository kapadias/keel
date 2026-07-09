---
description: Path-aware parallel review before merge — always a correctness review; adds a security review when the change touches auth, data, money, input handling, or anything outward-facing.
argument-hint: "[scope — paths/files; defaults to the current branch diff vs develop]"
model: opus
allowed-tools: Task, Read, Grep, Glob, Write, Bash(git diff:*), Bash(git branch:*), Bash(git status:*), Bash(git rev-parse:*), Bash(bash .claude/skills/code-review/scripts/check-review.sh:*)
---

!git branch --show-current
!git status --short
!git diff develop...HEAD --stat

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
3. **Persist each verdict — verbatim.** Every reviewer ends with exactly one fenced json verdict
   block. Write each block **byte-for-byte** — no merging, no rewriting, no "cleanup" — to
   `.claude/reviews/<sha>-code.json` and (when the security reviewer ran)
   `.claude/reviews/<sha>-security.json`, where `<sha>` is `git rev-parse --short HEAD`. These are
   transient gate inputs, git-ignored; a new commit invalidates them by construction.
4. **Run the gate — the script decides.** Run
   `bash .claude/skills/code-review/scripts/check-review.sh` on **each** verdict file. A non-zero
   exit means the review gate is red. Report the script's output as the verdict and **never
   override it** — the parser, not the model, decides merge-readiness (ADR-0005).
5. **Synthesize for the human.** Merge findings into one report, deduplicated, grouped by severity —
   **CRITICAL / HIGH / MEDIUM / LOW** — each with `path:line`, the issue, and a concrete fix. Any breach
   of a trust boundary, a safety gate, or "fail-closed" is automatically CRITICAL. The prose explains;
   the gate's exit code decides.

## Output

The gate result (per verdict file), then the consolidated, severity-grouped findings. If any issues
were fixed inline, note them and **re-run `/review`** — verdicts are per-commit. Update the tracked
issue with the outcome.

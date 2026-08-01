---
name: release
disable-model-invocation: true
description: Promote develop→main — human-gated production release. Creates the PR, requires explicit human approval before merge, then tags and publishes release notes.
argument-hint: "<version> [release notes summary]"
model: opus
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git status:*), Bash(git log:*), Bash(git tag:*), Bash(git push origin v:*), Bash(gh pr create:*), Read, Grep, Glob
---

!git branch --show-current
!git status --short
!git log main...develop --oneline 2>/dev/null || git log --oneline -20

Release: **$ARGUMENTS**

## Why this is gated

Merging `develop → main` is a **risk-increasing, outward-facing, production action** — it widens blast radius to real users. Per [`.claude/rules/safety.md`](../../rules/safety.md), this requires a human to approve before the merge executes. Do not merge on behalf of the user; open the PR and stop.

## Steps

1. **Confirm `develop` is green.** Run `/test` against `develop`. If anything is red, stop — do not open a release PR over a failing gate.
2. **Review the delta.** The `git log main...develop` output above is the full promotion scope. Summarize the changes, flag anything touching auth, data, money, or irreversible actions, and confirm no secrets or debug spew are present.
3. **Open the PR `develop → main`.** Title: `release: $ARGUMENTS`. Body: changelog derived from the commits above, test plan, and a prominent notice:

   > **HUMAN APPROVAL REQUIRED before merge.** This PR promotes to production. Review the delta, confirm the gate is green, then merge manually.

4. **Stop here.** Do not merge. Do not trigger a deploy. A human reviews and merges.
5. **After human merge** (when instructed to continue):
   - Tag the release: `git tag -a v$1 -m "Release $ARGUMENTS"` on `main`.
   - Push the tag: `git push origin v$1`.
   - Update `docs/STATUS.md` with the release version and date.
   - Run `/sync` to close the loop across all five mirrors.

## Output

The PR link, the delta summary, and an explicit note that merge is blocked on human approval. After merge: the tag, updated STATUS, and sync confirmation.

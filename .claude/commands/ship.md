---
description: Run the full local gate, then commit on a feature branch, push, and open a PR to develop linked to its tracked issue — and update STATUS. The disciplined path to merge.
argument-hint: "[optional: PR title / summary]"
---

Ship: **$ARGUMENTS**

## Steps

1. **Gate first — do not skip.** Run lint + type-check + tests + coverage (`/test`). If anything is
   red, stop and fix it. **Never ship with failing tests** (see
   [`.claude/rules/testing.md`](../rules/testing.md)).
2. **Branch check.** Ensure you are on a `feature|fix|chore|refactor/<id>-<slug>` branch, not
   `main`/`develop`. If not, create one and move your work (see
   [`.claude/rules/git-workflow.md`](../rules/git-workflow.md)).
3. **Review the whole delta:** `git diff develop...HEAD`. Confirm there are no secrets, no debug spew,
   no unrelated changes.
4. **Commit** in logical units with conventional-commit messages (`feat:`, `fix:`, …), referencing the
   tracked issue.
5. **Sync the mirrors** (`/sync`): update `docs/STATUS.md`, add an ADR if a decision was made, and move
   the tracked issue. The pre-push hook will block a code push that skips `docs/STATUS.md`.
6. **Push & PR:** `git push -u origin <branch>`, open a PR **to `develop`** (never straight to `main`),
   summarize the delta and the test plan, and **link the PR to the issue**. Paste the PR link back onto
   the issue.

## Guardrails

- PR target is `develop`. Only `develop → main` goes to production.
- Do not open a PR if the gate is red or the diff contains secrets.

## Output

The branch, the commit(s), the PR link, and a checked-off Definition-of-Done list.

# Rule: Git Workflow

Your issue tracker is the system of record. Git mirrors it. Every branch, commit, and PR traces back to
a tracked unit of work.

## Branching

- **Never commit to `main` or `develop`.** A hook warns on protected branches — branch first, do not
  bypass it.
- Branch from `develop`:
  ```bash
  git checkout develop && git pull
  git checkout -b feature/<id>-short-slug
  ```
- Naming: `<type>/<id>-<slug>` where `<type>` ∈ `feature | fix | chore | refactor`.
  - `feature/PROJ-204-oauth-device-flow`
  - `fix/PROJ-218-null-cursor-crash`
- One unit of work → one branch. Keep branches focused and short-lived.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

<optional body — the why, not the what>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`.

- Reference the tracked issue in the body or PR.
- Commit in logical, reviewable units; keep the working tree green per commit.
- Do not add AI/tool attribution or co-author trailers unless the project asks for them.

## Pull requests

```
feature/* → develop      (staging)
develop   → main         (production)
```

- Target `develop` from feature branches; target `main` only from `develop`.
- Before opening a PR, review the **whole** delta, not just the last commit:
  ```bash
  git diff develop...HEAD
  ```
- PR body: summarize all changes across the branch, list the modules touched, and include a test plan.
- **Link the PR to its tracked issue** and paste the PR link back onto the issue — it is part of the
  Definition of Done (see [sync.md](./sync.md)).
- Push new branches with `-u`: `git push -u origin feature/<id>-short-slug`.
- All changes go through PR review before merge (see [dev-process.md](./dev-process.md)).

## Deploys

Merges drive deploys: `→ develop` deploys staging, `→ main` deploys production. Treat a merge to `main`
as live. Only merge work that has cleared review and verification.

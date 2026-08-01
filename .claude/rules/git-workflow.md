# Rule: Git Workflow

Your issue tracker is the system of record. Git mirrors it. Every branch, commit, and PR traces back to
a tracked unit of work.

## Branching

- **Never commit to `main` or `develop`** — `guard-branch.sh` blocks it. Branch from `develop` first.
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
- Review the **whole** delta before opening (`git diff develop...HEAD`), not just the last commit.
- PR body: all changes across the branch, modules touched, and a test plan.
- **Link the PR to its tracked issue** and paste the link back onto the issue — part of the
  Definition of Done ([sync.md](./sync.md)).
- Push new branches with `-u`. All changes go through review before merge.

## Deploys

Merges drive deploys: `→ develop` deploys staging, `→ main` deploys production. Treat a merge to `main`
as live. Only merge work that has cleared review and verification.

# STATUS — Keel

The living status of the Keel harness itself. Adopters mirror this file for their own project; the
pre-push hook (`require-status-sync.sh`) blocks code pushes that leave it stale.

## Current state

**v0.1.0** — initial public release of the harness. Portable `.claude/` operating system for
disciplined, test-driven, review-gated AI-assisted development. Language- and domain-agnostic.

## What exists

- **Rules ×8** — `dev-process`, `testing`, `engineering`, `git-workflow`, `sync`, `boundaries`,
  `safety`, `token-economy`. The dense, always-on policy surface.
- **Agents ×7** — `orchestrator`, `implementer`, `test-engineer`, `code-reviewer`,
  `security-reviewer`, `explorer`, `debugger`.
- **Skills ×5** — `tdd-workflow`, `code-review`, `debugging`, `refactoring`, `api-design`.
- **Commands ×10** — `/plan`, `/tdd`, `/implement`, `/review`, `/test`, `/debug`, `/ship`, `/sync`,
  `/adr`, `/intake`.
- **Hooks ×3** — `guard-branch.sh` (PreToolUse), `format.sh` (PostToolUse),
  `require-status-sync.sh` (pre-push git hook).
- **Settings** — `.claude/settings.json` wiring the hooks and the read-deny posture for `.env` and
  `secrets/**`.
- **Docs** — this `STATUS.md`, the `docs/adr/` index, and ADRs 0001–0003.
- **CI** — `.github/workflows/ci.yml`: `shellcheck` on hooks + `harness-lint` on agent/command
  frontmatter.

## Recently changed

- **2026-06-22** — Initial harness extracted and generalized; published to `kapadias/keel`.

## Next / open

- Add language-specific quickstart recipes (Python, TypeScript, Go) wiring `/test` to a real gate.
- Optional MCP server examples for the explorer and reviewer agents.
- Expand the ADR set as load-bearing decisions accrue (via `/adr`).

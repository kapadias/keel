# Changelog

All notable changes to Keel. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning is [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Automated releases.** Pushing a `v*` tag now publishes the GitHub Release itself, with notes read
  from this file. v1.0.0 was assembled by hand, and the hand-assembly is exactly what argued for
  this: `git tag -F` defaults to `--cleanup=strip`, which deletes every `#`-prefixed line, so the
  annotation lost all its markdown headings and a breaking change read like a feature. The tag is now
  the trigger; `CHANGELOG.md` is the source of truth. The workflow refuses to publish when the
  section is missing or empty, and refuses when the tag disagrees with the plugin manifests.
- `.github/scripts/release-notes.sh` — the extractor, as a script rather than inline YAML so it is
  golden-tested like every other gate here. Nine tests, including that dots in a version are escaped
  rather than acting as regex wildcards.

### Changed

- **The banner carries no version and no licence.** `assets/keel-banner.svg` hardcoded `v0.1.0` and
  `MIT` — the version was two releases stale and nobody noticed, which is the argument against
  putting expiring facts in a hand-edited image. The `License` and `release` badges are gone from the
  README header for the same reason. The live version lives in `CHANGELOG.md` and the manifests; the
  licence lives in `LICENSE`.

## [1.0.0] — 2026-08-01 — "The Model Cannot Ship Itself"

The first published release. Keel has existed since 2026-06-22 and reached v0.2.0 internally, but no
tag or GitHub release was ever cut — the manifests claimed `0.2.0` against no artifact. This is the
first real one.

### ⚠️ Breaking

- **`.claude/commands/` no longer exists.** All 14 pipeline workflows moved to
  `.claude/skills/<name>/SKILL.md`. Claude Code merged custom commands into skills, and only skills
  support invocation control, bundled supporting files, and `context: fork`. Every `/name` still
  works exactly as before — but anyone who copy-installed a v0.2-era `.claude/` and pulls these files
  in piecemeal must delete their `commands/` directory, or the same `/name` will resolve twice.
- **The always-on rule set changed shape.** A new `.claude/rules/00-core.md` is now the constitution
  the other eight rules elaborate; `CLAUDE.md` dropped from 836 to 234 words. If you have local edits
  to `CLAUDE.md` or the rules, re-apply them against the new structure rather than merging blindly.

### Added

- **`Stop` gate** (`stop-dod.sh`) — a turn cannot end with tracked code changed and `docs/STATUS.md`
  untouched. The pre-push Definition-of-Done gate fired too late; by push time the agent had usually
  declared "done" several turns earlier. Deliberately narrow: reading, planning, doc-only edits and
  untracked scratch all end freely, and it fails **open** outside a git repo.
- **`SubagentStop` gate** (`subagent-verdict.sh`) — runs the existing `check-review.sh` against the
  reviewer's own output, so ADR-0005's machine-checkable verdict binds where the verdict is
  _produced_, not several steps later. A reviewer returning prose is now caught immediately.
- **`PostCompact` hook** (`post-compact.sh`) — restates branch, HEAD, uncommitted count, STATUS state
  and whether review verdicts exist for the current SHA. Compaction keeps the narrative and drops the
  bookkeeping, which is exactly the state the gates key on.
- **`rules/00-core.md`** — the constitution, and the only thing a plugin install receives. Budgeted
  under 9,000 characters so it fits the 10,000-character `SessionStart` channel.
- **`CHANGELOG.md`** (this file) and **ADR 0007**.
- Agents gained `skills:` preloading (`code-reviewer` ← `code-review`, `security-reviewer` ←
  `security-review` + `code-review`, `debugger` ← `debugging`, `test-engineer` ← `tdd-workflow`),
  plus `effort:` and `maxTurns:`.
- `fable` accepted as a model tier.

### Changed

- **Six workflows are human-only.** `/ship`, `/release`, `/rollback`, `/adr`, `/sync` and `/intake`
  set `disable-model-invocation: true`. Claude cannot trigger them, and their descriptions leave the
  context window entirely. `rules/safety.md` always said a human approves promotion to production;
  this makes it a mechanism instead of a request, and the linter asserts it.
- **Always-on context down ~24%**, ~9.1k → ~6.9k tokens per turn: prose 4,252 → 3,599 words,
  description metadata 6,952 → 4,389 characters. Every cut removed content that was stated two or
  three times _within the always-on surface itself_.
- Budgets tightened and newly enforced: `CLAUDE.md` 900 → 300 words, per-rule 700 → 520, total
  always-on 4,500 → 3,700, plus new caps on `00-core.md` size and total description metadata.
- Golden tests 78 → 136. `harness_lint.py` grew roughly 13 → 22 distinct checks.
- `docs/INSTALL.md` no longer claims the two install paths "end with the same harness". They do not.

### Fixed

- **The Definition-of-Done gate was silently absent under a plugin install.** `session-start.sh`
  guarded the pre-push install on a project-relative path that does not exist there, so it no-opped
  without a word. It now resolves from `${CLAUDE_PLUGIN_ROOT}` and **warns** when it can locate
  neither source. This was the one true fail-open in the harness.
- **Gate scripts were unreachable under a plugin install.** `/review`, `/ship` and `/fix` invoked
  `check-review.sh` and `check-trivial.sh` through hardcoded `.claude/skills/…` literals.
  `SessionStart` now announces the resolved harness root. (These failed _closed_ — exit 127 blocks
  the ship — so the commands were unusable rather than unsafe.)
- **Four workflows could not run their own instructions.** `allowed-tools` is a pre-approval grant,
  so a missing entry halts for approval interactively and is denied outright in non-interactive runs.
  `/ship` lacked `git add` and any branch verb; `/release` lacked `git push` while its step 4 says
  "Push the tag"; `/adr` lacked `Edit` while its step 3 says "Link it from the ADR index";
  `/rollback` lacked a branch verb.
- **ADR-0006 asserted that `rules/` is a plugin component.** It is not — Claude Code's plugin schema
  has no `rules` component — so a plugin install loaded none of the operating discipline. Superseded
  by ADR-0007; `session-start.sh` now carries `00-core.md` through `additionalContext`.
- `harness_lint.py` rejected `fable`, blocking adopters from using a current model tier, and its
  calibration comment was stale.

### Known limitations

- A plugin install still receives only `00-core.md`, not the full rule set, and cannot inherit
  `settings.json` permissions. Both are documented in `docs/INSTALL.md` with a copy-in remedy.
- The plugin-path fixes are proven by golden tests that simulate `CLAUDE_PLUGIN_ROOT`, **not** by an
  observed `/plugin install`.
- Still open from the roadmap: a statusline, orphan detection in the linter, a markdownlint CI job,
  and behavioral (transcript-graded) evals.
- Persistent agent `memory:` was evaluated and **deliberately rejected** — it is LLM-authored state
  that steers future sessions with no gate in front of it, which `boundaries.md` forbids. Adopting it
  requires an ADR and a validation gate first.

## [0.2.0] — 2026-06-23 — "Gates as Code" (never published)

Turned prose discipline into blocking scripts: `guard-branch.sh`, `secret-scan.sh`, the pre-push
Definition-of-Done hook, the machine-checkable review verdict (ADR-0005), the `/fix` bounded fast
lane, stack packs for python/typescript/go/rust, and plugin distribution (ADR-0006).

## [0.1.0] — 2026-06-22 (never published)

Initial harness: rules, agents, skills, commands, and the development loop — described, not yet
enforced.

[1.0.0]: https://github.com/kapadias/keel/releases/tag/v1.0.0

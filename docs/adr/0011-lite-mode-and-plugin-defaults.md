# ADR 0011 — Lite mode and plugin defaults

- **Status:** Accepted; amends [0007](0007-plugin-install-is-not-equivalent.md) and
  [0008](0008-decision-ladder-for-solution-size.md)
- **Date:** 2026-09-25
- **Deciders:** Shashank Kapadia

## Context

The README told people to install a plugin that did not deliver the product:

- **No test gate.** A plugin install ran the tests only once the user set `NONNA_TEST_CMD`, because
  nobody had agreed to have each repository's code run at every turn end. [ADR 0004](0004-gates-as-code.md)
  already names the cost: a gate that must be opt-in is missing on day one for everyone.
- **A gate for a file nobody had.** The `docs/STATUS.md` gate blocked turns, and the user's own
  pushes, in repositories that never kept the file.
- **Guards that did not travel.** Force pushes and reads of `.env` were refused by `settings.json`
  permissions, which a plugin cannot carry.
- **A hook that went quiet.** The pre-push link pointed into the versioned plugin cache, which an
  update deletes, and git skips a hook it cannot find without a word.

Cost pointed the same way. Benchmark rounds 1 and 2 priced a copy-in install well above a bare agent
per change, and most of the spend was review, not the gates ([ADR 0009](0009-proportional-review.md)).
The safety result looked like it came from the gates and the never-list: the test gate caught
claims of done, and the rules kept agents off `main` and away from secrets. A mode with only those
might keep most of the result at close to bare cost. Round 3 of the benchmark tests that under a
table written before the paid runs.

[ADR 0008](0008-decision-ladder-for-solution-size.md) rejected intensity modes as YAGNI: "there is no
lighter mode to select". A plugin user's first day is that use.

## Options considered

1. **One mode, fix only the defects.** Least code. But the first day still carries the most
   opinionated parts (the STATUS gate, about 2k tokens of constitution every turn, the
   develop-to-main flow), and those are not what moved the safety numbers.
2. **A second, lite plugin.** A clean split, but two roots to version, validate and document, and a
   reinstall to change your mind.
3. **Intensity levels the model sets**, the shape ADR 0008 already turned down. Still rejected: a
   mode the model can change has no gate in front of it.
4. **One plugin, three modes (`off | lite | full`), set by the user in git config** (chosen).

## Decision

1. **Modes.** `nonna_mode` (`.claude/hooks/lib/core.sh`) resolves `NONNA_MODE` > `git config
nonna.mode` (repo, then global) > the plugin's `mode` option > `git config nonna.defaultMode` >
   the install (copy-in full, plugin lite). git config because Claude Code hooks and git hooks can
   both read it, it is never committed, and a clone cannot carry it. A value nobody meant fails
   closed to full; it never weakens the gates. In `off` every hook exits 0 and prints nothing.
2. **`nonna.mode` is the user's alone.** What Nonna records, the `mode` option mirrored each session
   for git hooks that cannot see it or `install.sh --mode`, goes in `nonna.defaultMode`, below it,
   so `git config --global nonna.mode off` reaches every repository the user has not set. (The draft
   recorded `nonna.mode` on first sight, which would have outranked the global switch everywhere
   Nonna had been.) The branch guard refuses an agent's `git config nonna.*` writes, including
   inside a heredoc: a model does not switch off its own gates. It is a speed bump, not a sandbox.
3. **Lite** is the test gate, "where's the test?", the branch guard, the secret guard, the git hooks
   and six house rules (`.claude/hooks/lib/lite.md`, linted to 150 words and to cover the never-list's
   tests, branch and secret lines). **Full** adds the STATUS gate, the constitution and the
   develop-to-main flow. Lite is the plugin's default; copy-in stays full until round 3 decides.
4. **The plugin's test gate is on, with recorded consent.** The `run_tests` option (on, asked at
   enable) is the consent. The first session in a repository records the detected command in `git
config nonna.testCmd` and never overwrites it, an empty one included. The command resolves
   `NONNA_TEST_CMD` > `nonna.testCmd` > detection, and detection is copy-in only.
5. **The STATUS gate is full mode's**, and only where `docs/STATUS.md` exists: at Stop and pre-push.
6. **Plugin git hooks survive updates.** `pre-push` and `pre-commit` link through
   `${CLAUDE_PLUGIN_DATA}/current`, which each session points at the running version. A dangling
   link of Nonna's is repaired; a foreign hook is never overwritten; a hook manager is reported.
7. **The guards live in hooks.** The branch guard refuses force pushes, `--no-verify` and hook-path
   overrides; the secret guard refuses reads of secret files, linted against `settings.json`'s
   deny-list so the two cannot drift.
8. **Two Stop checks were added in both modes.** "Where's the test?" blocks once when source changed
   and no test did. A per-session base means work committed during the session is still checked.
9. **The ladder is said once.** In full mode, when another enabled plugin already states the "reuse
   before you write" ladder, the carrier drops the constitution's copy. Only
   `.claude/hooks/lib/ladder.sh` names that plugin; `NONNA_LADDER=on|off` overrides it.

## Consequences

- A plugin install does what the README says on its first session, with nothing to configure.
- **The git hooks now reach people, not only agents**: anyone who commits or pushes in a repository
  where a session ran. That is the point of a gate, and it is announced: the first session tells the
  user what Nonna added, once per repository per major version (`nonna.announced`). The ways out are
  `nonna.mode off` (repo or `--global`) and the removal steps in [INSTALL.md](../INSTALL.md).
- State lives in `.git/config`, `.git/hooks` and `.git/nonna/`, never in a commit. Uninstalling the
  plugin leaves the git hooks dangling, which git skips, so the removal steps come first.
- `run_tests` decides only on first sight. Turning it off later does not reach a repository that
  already recorded a command; `nonna.testCmd` decides there. Revisit if users expect otherwise.
- Lite still loads every agent and skill, because it is one plugin; the house rules tell the agent
  to run them only when asked. Round 3 counts subagent spawns. If unasked reviews show up, the agent
  descriptions become mode-neutral.
- ADR 0007: the carrier now carries by mode (`lite.md` or `00-core.md`). ADR 0008: "no lighter mode"
  no longer holds; its rejection of model-set intensity stands.
- Revisit lite as the default if round 3 shows it leaking against the pre-registered table.

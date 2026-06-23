# 0006 — Distribute Keel as a plugin (zero-duplication)

One source of truth, versioned and installable. The existing `.claude/` directory is the plugin root;
no separate distribution tree.

## Status

Accepted

## Date

2026-06-23

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

Keel's v0.1 distribution model was **copy the `.claude/` directory** into a target repository. This
worked as a bootstrapping mechanism but carried compounding costs at scale:

- **No versioning.** A team that copied Keel in January and another that copied it in April have
  silently diverged. There is no declared version, no diff, and no upgrade path. The harness that
  preaches "reconcile, don't assume" had no reconciliation mechanism for its own distribution.
- **No discovery.** Keel was findable only by word of mouth or by knowing to look at the repository.
  The Claude Code plugin marketplace provides structured discovery — search, install, update — that a
  copy-paste workflow cannot replicate.
- **Maintenance burden.** Bug fixes and new capabilities required every adopter to manually re-copy or
  hand-merge changes. In practice this meant copies drifted and the harness degraded silently, exactly
  the failure mode that the sync rule ([sync.md](../../.claude/rules/sync.md)) is designed to prevent.

Claude Code's plugin system addresses all three: plugins are versioned, discoverable via
`/plugin marketplace add <owner>/<name>`, and updatable. The question is how to structure Keel as a
plugin without introducing a second source of truth. Claude Code plugins expect component directories
(`agents/`, `skills/`, `hooks/`, `commands/`) at the **plugin root**. Keel already has exactly this
structure — under `.claude/`. A naive approach would duplicate the tree into a `dist/` directory
maintained separately, which trades one set of problems (no versioning) for another (two sources of
truth that drift).

## Options considered

1. **Do nothing — standalone copy only.** Keep the current "clone and copy `.claude/`" model.
   Document it better; add a CHANGELOG.
   - Adds a CHANGELOG, which is net positive regardless. But it does not solve versioning (adopters
     still pin nothing), discovery (the marketplace is still unavailable), or the update path (still
     manual re-copy). Keel's own distribution would contradict the sync and reconciliation discipline
     it enforces on every project it governs.

2. **Duplicate into a `dist/` plugin tree.** Build a release step that copies `.claude/` into
   `dist/` with a `plugin.json` manifest at `dist/`. Publish `dist/` as the plugin root.
   - Solves versioning and discovery. Introduces a new problem: `dist/` is a second source of truth
     for every agent, skill, hook, command, and rule in the harness. Any change to `.claude/` that
     is not reflected in `dist/` silently degrades the published plugin. The release step becomes a
     maintenance liability. Two trees means two reviews, two test surfaces, and two opportunities to
     drift — precisely the anti-pattern that [ADR 0002](0002-llm-proposes-gates-decide.md) and
     [sync.md](../../.claude/rules/sync.md) exist to prevent.

3. **Reuse `.claude/` as the plugin root directly** (chosen). The Claude Code plugin manifest lives at
   `.claude/.claude-plugin/plugin.json`. A repo-root `.claude-plugin/marketplace.json` declares the
   plugin with `"source": "./.claude"` — a relative subdirectory source, which the marketplace spec
   supports. All component directories (`agents/`, `skills/`, `hooks/`, `commands/`, `rules/`) are
   already at the correct relative paths within the plugin root. There is no duplication and no
   release-time copy step: what ships is what runs. Hooks are declared in `hooks.json` at the plugin
   root so they wire correctly on install.
   - One known limitation: a plugin's `settings.json` is honored only for `agentStatusLine` and
     `subagentStatusLine`; the read-deny permission posture (blocking `.env`, `secrets/**`, dangerous
     Bash patterns) cannot be injected into the host project's settings through the plugin mechanism
     alone. This must be documented explicitly: adopters add the deny-list entries to their own
     `settings.json`. The limitation is bounded and fixable as the plugin spec matures; the
     zero-duplication invariant is not.

## Decision

Keel is distributed as a Claude Code plugin whose **root is the existing `.claude/` directory**.

- `.claude/.claude-plugin/plugin.json` is the plugin manifest: it declares the plugin name, version,
  description, and component paths relative to `.claude/`.
- `.claude-plugin/marketplace.json` at the repository root is the marketplace registration, with
  `"source": "./.claude"` pointing to the plugin root as a subdirectory.
- Hooks are declared in `.claude/hooks.json` so that a plugin install wires them without requiring the
  adopter to run a SessionStart hook manually. (The SessionStart auto-install from
  [ADR 0004](0004-gates-as-code.md) remains in place for standalone-copy adopters.)
- The plugin is installable via `/plugin marketplace add kapadias/keel` and updatable in place.
  Standalone-copy adoption continues to work unchanged — the plugin structure is additive, not a
  replacement.
- The permission-posture limitation is documented in `docs/INSTALL.md`: adopters must add Keel's
  deny-list entries to their own project `settings.json`. A template block is provided; the install
  documentation makes the required manual step explicit and mechanical.

## Consequences

- **One source of truth.** Every agent, skill, hook, command, and rule exists in exactly one place.
  A change to `.claude/rules/boundaries.md` is immediately reflected in the published plugin; there is
  no sync step, no release copy, and no opportunity for the two to diverge.
- **Versioned and discoverable.** Adopters install a declared version and receive updates through the
  standard plugin mechanism. The CHANGELOG is the migration guide. Keel's own harness now satisfies
  the sync discipline it imposes on others.
- **Standalone copy still works.** Teams that prefer to fork the `.claude/` directory and own their
  own copy are unaffected. The plugin structure is purely additive metadata.
- **Known limitation: settings.json permission posture is not injected.** The plugin mechanism does
  not propagate deny-list entries to the host project. Adopters must add them manually. This is a
  real gap — a freshly installed plugin without the deny-list has weaker secret protection than a
  fully configured standalone copy. The `docs/INSTALL.md` template and the SessionStart hook
  (which can check for missing entries and warn) mitigate this; the gap should be revisited as the
  plugin spec evolves.
- **`plugin.json` and `marketplace.json` are harness files and are treated as code.** Changes to
  either go through the same review and gate process as any other `.claude/**` file (see
  [ADR 0004](0004-gates-as-code.md)). A malformed manifest that breaks plugin installation is a
  regression, not a configuration typo.

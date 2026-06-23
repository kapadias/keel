# 0004 — Gates as code, not prose

A harness that preaches gates but enforces with paragraphs fails open. Keel's hooks are blocking,
deterministic, and auto-wired — locally and in CI.

## Status

Accepted

## Date

2026-06-23

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

Keel's headline principle is "the LLM proposes; deterministic gates decide" (see
[ADR 0002](0002-llm-proposes-gates-decide.md)). In v0.1 the gap between the principle and the
implementation was wide:

- **guard-branch** only _warned_. An agent or distracted engineer could acknowledge the warning and
  commit to `main` or `develop` anyway. Warning-mode protection is not protection — it is a suggestion
  that survives ignoring.
- **require-status-sync** (the pre-push hook that enforces the Definition of Done) was never wired
  automatically. It required a manual `ln -s` after cloning, so virtually no new adopter had it
  running. A gate that must be opt-in is missing on day one for everyone.
- **No secret-scan on writes.** The `settings.json` deny-list blocked _reading_ `.env` and
  `secrets/**`, but nothing blocked an agent from _writing_ a high-confidence secret pattern (an API
  key, a private key header, a bearer token) into a source file and committing it.
- **Agent "never push/deploy" rules were unenforced.** They appeared as prose in `.claude/rules/` and
  in agent system prompts. There was no hook or CI step that verified the invariant — it depended
  entirely on the model respecting instructions it had read, which is exactly what
  [boundaries.md](../../.claude/rules/boundaries.md) says is insufficient.

The net effect: the harness read like it had gates; it behaved like it had honor-system reminders. A
system that fails open on the exceptions — the tired session, the misconfigured clone, the adversarial
input — is not a safety system. The gates must run _before_ the consequence, on every path, regardless
of how the session started.

## Options considered

1. **Do nothing — keep warn-only prose.** Leave guard-branch in warning mode, accept that
   require-status-sync will often be missing, add no secret scan. Rely on engineers reading and
   respecting the rules.
   - Requires no engineering effort and produces no friction. Also produces no enforcement.
     Warn-only gates fail open on every path that matters: the mistake, the hurry, the misconfigured
     clone. A harness whose gates are wishes is the same as no harness, with added ceremony.

2. **Enforce only in CI — server-side, after the fact.** Add branch protection rules, secret scanning,
   and status-sync checks in the CI pipeline. Local hooks remain advisory.
   - CI enforcement is a real backstop and should always exist, but "catch it in CI" means a commit
     carrying a secret, or a force-push to `main`, has _already happened_ before anything blocked it.
     For secret exposure and protected-branch corruption, the damage is done at commit time, not at
     merge time. Server-side-only enforcement also creates a class imbalance: commits from engineers
     with full repo access bypass local hooks trivially, while CI has no opinion until push.

3. **Make hooks blocking, deterministic, and auto-wired locally** (chosen). Hooks are not warnings;
   they are gates. guard-branch exits non-zero on a `git commit`/`git merge` on a protected branch (and
   on a `git push` that is on, targets, or `--all`/`--mirror`-spans one); edits to a protected branch
   warn but do not block, because editing is not the irreversible step. A secret-scan hook runs at write
   time (PreToolUse on Edit/Write/MultiEdit) and blocks content matching a high-confidence secret shape
   (AWS/GitHub/Slack/Google/Stripe/OpenAI keys, PEM private-key headers, hardcoded credential
   assignments), naming the match class; the pre-push hook scans the pushed range as a second line.
   require-status-sync is auto-installed during SessionStart — no manual setup, no opt-in. The
   `settings.json` deny-list blocks reading secret files and `git push --force`; coarser irreversible
   Bash is left to review and the human gate rather than blunt prefix-matched denies. `.claude/**` is
   treated as code: hooks ship as executable, version-controlled scripts, not prose. CI remains the
   external backstop; local hooks are the first line.
   - Introduces the possibility of a false stop — a legitimate secret rotation commit blocked by the
     scanner, a developer who needs to hotfix `main` directly. These are recoverable: the developer
     overrides with explicit intent (the override itself becomes the audit trail). Per
     [safety.md](../../.claude/rules/safety.md), a false stop costs time (recoverable); a missed stop
     can cost the system (terminal). The asymmetry decides the trade.

## Decision

Keel's gates are **code, not prose**: executable, blocking, and auto-wired from the first session.

- **guard-branch** exits 2 on a `git commit`/`git merge` while on `main`/`master`/`develop`, and on a
  `git push` that is on, targets (including a `refs/heads/<branch>` refspec), or `--all`/`--mirror`-spans
  a protected branch. The matcher tolerates global options (`git -C`, `--git-dir`, a path-prefixed
  binary) so it is not trivially evaded. Edits to a protected branch warn only — committing is the gated
  step, not editing.
- **secret-scan** runs at write time (PreToolUse on Edit/Write/MultiEdit) and blocks content matching a
  high-confidence secret shape; the pre-push hook additionally scans the pushed range. The scan is
  deterministic and pattern-matched — no model inference in the critical path — and **fails closed when
  `jq` is absent** (it scans the raw payload rather than trusting a lossy parse), with the
  placeholder/example exemption applied to the matched value (not the whole line) so a trailing comment
  cannot smuggle a key past.
- **require-status-sync** is installed via a SessionStart hook. On first session in any clone the
  pre-push hook is created; subsequent sessions are no-ops. The Definition of Done is enforced from day
  one, not after the engineer discovers the manual step.
- **settings.json deny-list** blocks reading secret files (`.env`, `*.pem`, `*.key`, `~/.ssh`, `~/.aws`,
  …) and `git push --force`. It is defense-in-depth, not the primary push gate — guard-branch is — so it
  deliberately is not a comprehensive blunt-deny of every dangerous Bash string.
- **CI remains the backstop.** Branch protection, secret scanning, and status-sync checks run server-
  side. Local hooks are the first gate; CI is the second. A change that slips past a misconfigured
  local environment is still caught before merge.

The governing rule lives in [`.claude/rules/boundaries.md`](../../.claude/rules/boundaries.md): when
the safety layer and "move fast" disagree, the safety layer wins.

## Consequences

- **Gates run before the consequence** — at commit, at push, not at review or after merge. Secrets,
  protected-branch writes, and missing status-sync are caught at the earliest possible point.
- **The harness is self-wiring.** A fresh clone that opens a Claude Code session immediately gets the
  correct hooks. There is no documentation step that must be followed; the SessionStart hook is the
  documentation.
- **False stops are expected and acceptable.** A developer performing a legitimate exception (direct
  `main` hotfix, intentional secret rotation commit) must override explicitly. The override is
  recoverable and leaves a trail. The alternative — a gate that can be ignored — is not a gate.
- **CI remains required.** Local hooks are a developer convenience and a fast-feedback mechanism; they
  are not a substitute for server-side enforcement. Both must exist. A security posture that depends on
  every developer's local environment being correctly configured is fragile; CI is the hard backstop
  that cannot be bypassed by a misconfigured clone.
- **`.claude/**` is under version control and treated as production code.\*\* Hook scripts are reviewed,
  tested, and versioned with the same rigor as application code. A hook that silently fails is worse
  than no hook — it provides false assurance. Hook exit codes are tested in CI.

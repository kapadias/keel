# 0005 — Machine-checkable review verdict

Review is a gate only if its output is machine-readable. Prose verdicts are advisory; a structured
JSON block parsed by a committed script is deterministic.

## Status

Accepted

## Date

2026-06-23

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

Keel's dev loop gates merges on review (see [dev-process.md](../../.claude/rules/dev-process.md)).
In v0.1 the `code-reviewer` and `security-reviewer` agents produced **prose verdicts** — paragraphs
of findings, a summary sentence, sometimes an explicit "approved" or "changes requested" embedded in
free text. A human still had to read the prose and decide whether review had passed. This made "review
is a gate" aspirational rather than enforced:

- There was no machine-readable signal. `/ship` could not inspect the reviewer's output and block on
  a CRITICAL finding; it could only check whether a review _had been run_, not whether it _had passed_.
- Severity was inconsistent. Without a schema, different reviewer invocations used different words
  for the same concept ("blocking" vs. "critical" vs. "must fix"), making automated triage impossible.
- The reviewers were the _deciders_, not advisory inputs. [boundaries.md](../../.claude/rules/boundaries.md)
  is explicit: "the output of an LLM is a proposal, never the final authority." When a prose verdict
  from a model agent _is_ the verdict, the gate is an LLM's opinion — precisely what the principle
  prohibits on anything consequential.
- A passing review left no auditable artifact. There was no committed record of _why_ a change was
  approved or what was checked, only the agent's transient context.

The review agents are valuable. The problem is not their judgment — it is that their judgment was
unstructured, making it impossible for any downstream step to consume it deterministically.

## Options considered

1. **Do nothing — prose verdict, human reads it.** Reviewers continue to emit free-text. A human
   developer reads the output, forms an opinion, and decides whether to proceed.
   - The human remains in the loop, which is appropriate for risk-increasing actions. But "a human
     read the text" is not a gate — it is a ritual with no enforcement. A tired developer skims a
     long verdict and misses a CRITICAL finding. The `/ship` command cannot distinguish a reviewed-and-
     approved change from a reviewed-and-ignored-findings change. The review step adds no deterministic
     signal to the pipeline.

2. **Rely on human reading with a structured template (no parser).** Give reviewers a required output
   template — headings, severity labels — but parse nothing automatically. The human is still the sole
   consumer.
   - Better than pure prose: consistent structure aids human reading, and severity labels become
     comparable across invocations. But without a parser that can enforce the output and block on
     findings, the gate is still aspirational. A reviewer that emits the wrong structure silently
     degrades to option 1.

3. **Require a structured JSON verdict block parsed by a committed script** (chosen). Reviewers **must**
   emit a structured block — a `verdict` field (`approve` | `request_changes`) and a `findings` array
   where each entry carries `severity` (CRITICAL | HIGH | MEDIUM | LOW | INFO), `path`, `line`,
   `category`, `issue`, and `fix`. A committed parser script,
   `.claude/skills/code-review/scripts/check-review.sh`, extracts the block and exits non-zero on
   `request_changes` or any finding at CRITICAL or HIGH severity. `/ship` calls the parser; the parser
   decides. The prose narrative remains (and must be consistent with the JSON) — it is the _explanation_
   that a human reads; the JSON is what the pipeline reads.
   - The reviewers are now **advisory inputs to a deterministic decider** — exactly the role
     [boundaries.md](../../.claude/rules/boundaries.md) prescribes for LLM components. The parser is
     not an LLM; it does not interpret; it matches schema and severity. A verdict that fails schema
     validation is treated as `request_changes` — the gate fails closed, not open.

## Decision

Keel's review gate is machine-checkable. `code-reviewer` and `security-reviewer` agents **must** emit
a JSON block conforming to the review-verdict schema as part of every verdict. The schema:

```json
{
  "verdict": "approve | request_changes",
  "summary": "<one-line prose>",
  "findings": [
    {
      "severity": "CRITICAL | HIGH | MEDIUM | LOW | INFO",
      "path": "<file path or null>",
      "line": "<line number or null>",
      "category": "<correctness | security | test-coverage | style | ...>",
      "issue": "<what is wrong>",
      "fix": "<what to do>"
    }
  ]
}
```

`.claude/skills/code-review/scripts/check-review.sh` is the deterministic decider: it extracts the
JSON block from reviewer output, validates the schema, and exits non-zero on `verdict:
request_changes` or any finding at CRITICAL or HIGH severity. `/ship` runs this script; a non-zero
exit blocks the merge. The script is committed, version-controlled, and tested in CI — it is code, not
a convention.

The prose narrative around the JSON block is retained as required context for human review, but it is
**not** what the pipeline acts on. If prose and JSON diverge, the JSON governs, and the reviewer must
be corrected. A reviewer whose JSON and prose tell different stories is emitting inconsistent output
that must be flagged.

## Consequences

- **Review verdicts are now composable with `/ship` and CI.** A merge cannot proceed with
  `request_changes` or an unaddressed CRITICAL/HIGH finding; the pipeline enforces it, not a norm.
- **The reviewers remain advisory.** They propose a verdict; the deterministic parser decides whether
  the gate passes. This preserves the principle from [ADR 0002](0002-llm-proposes-gates-decide.md):
  an LLM's output — including a review verdict — is a _proposal_. The schema parser is the gate.
- **Schema validation fails closed.** A reviewer that emits malformed JSON, omits the block, or uses
  an out-of-schema severity value causes the gate to return `request_changes`. There is no ambiguous
  middle state that passes by default.
- **The JSON and prose must be kept consistent.** Reviewers carry a new authoring obligation: the
  structured block is not a postscript appended after the narrative — it is the machine-readable
  expression of the same judgment. Inconsistency between them is itself a finding.
- **Audit trail.** The JSON block in the PR comment or review transcript is a committed, auditable
  record of what the reviewer found and why the gate passed or was blocked. "What was checked?" has a
  deterministic, inspectable answer after the fact.
- **False negatives remain possible.** The parser enforces schema and severity thresholds; it cannot
  enforce that the reviewer _found_ every bug. The quality of findings is still a function of the
  review agents' capability. The gate catches structurally defective verdicts and flagged findings; it
  does not substitute for good review prompts and sufficient coverage.

## Amendment (2026-07-09)

The implementation as shipped had drifted from this record in three ways; the schema is amended to
match the code where the code is right, and the code was fixed where it failed open:

- **Severity enum is `CRITICAL | HIGH | MEDIUM | LOW`** — `INFO` is dropped (it added nothing over
  LOW and no reviewer emits it). The category for test gaps is `tests`, matching the agents and
  `templates/verdict.json`.
- **Fail-closed is now provable, not promised.** As first shipped, `check-review.sh` blocked only on
  the literal `request_changes` / `CRITICAL|HIGH` values: an out-of-schema verdict (`"lgtm"`, or a
  missing field) exited 0, and an out-of-schema severity (`"BLOCKER"`) did not block. Both now fail
  as this ADR always claimed — unknown verdict → exit 2, unknown severity → exit 1 — with golden
  tests in `tests/run.sh` pinning each case.
- **Extraction lives in the script.** `check-review.sh` accepts either pure JSON or reviewer prose
  containing exactly one ```json fenced block; zero-after-fence or multiple blocks fail closed as
  ambiguous. The orchestrating LLM never hand-extracts the block — that step is deterministic.

`/ship` and `/review` are wired to run the script (see the commands); the "the parser decides" claim
in this ADR is true as of this amendment.

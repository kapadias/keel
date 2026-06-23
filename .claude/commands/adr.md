---
description: Write a numbered Architecture Decision Record in docs/adr/NNNN-<slug>.md capturing the context, the options considered, the decision, and its consequences.
argument-hint: "[the decision to record]"
model: opus
allowed-tools: Bash(ls:*), Read, Write, Glob
---

!ls docs/adr 2>/dev/null || echo "(no docs/adr directory yet — NNNN starts at 0001)"

Record the decision: **$ARGUMENTS**

## Steps

1. **Find the next number.** The `ls docs/adr` output above shows existing ADRs; use the next zero-padded `NNNN`. Slugify the title.
2. **Write `docs/adr/NNNN-<slug>.md`** using the template below. Be concrete: the value of an ADR is the
   _alternatives you rejected and why_, not the choice alone.
3. **Link it** from the ADR index (`docs/adr/README.md`) and from the tracked issue.

## Template

```markdown
# NNNN. <Decision title>

- Status: Proposed | Accepted | Superseded by ADR-XXXX
- Date: YYYY-MM-DD
- Deciders: <who>

## Context

What forces are at play — technical, product, and constraints. Why a decision is needed now.

## Options considered

1. **<Option A>** — pros / cons.
2. **<Option B>** — pros / cons.
3. **<Option C>** — pros / cons. (at least three; "do nothing" counts)

## Decision

The option chosen, in one or two sentences, and the decisive reason.

## Consequences

What becomes easier, what becomes harder, what we now must maintain, and what would make us revisit
this.
```

## Output

The path to the new ADR and a one-line summary of the decision. If this changed scope or the harness,
run `/sync`.

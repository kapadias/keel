# 0002 — The LLM proposes; deterministic gates decide

Keel's load-bearing principle, recorded. This is the line the whole harness is built to defend.

## Status

Accepted

## Date

2026-06-22

## Deciders

Keel maintainers (owner: Shashank Kapadia)

## Context

LLM coding agents are powerful and fast, and they are **probabilistic**. They can be confidently
wrong — plausible diffs that compile, read well, and are subtly incorrect; invented APIs; silent
regressions. When that output touches production, money, or data without an independent check, the
blast radius is real and the failure mode is *fails-open*: wrong work flows downstream because nothing
stopped it.

A harness for serious work cannot rest on the model being right. It must rest on something
deterministic being able to say **no**.

## Options considered

1. **Trust the model; review casually.** Accept agent output, skim it, merge.
   - Fast and frictionless. But "looks right" is not "is right"; the deciders are a tired human's
     glance and the model's own confidence. This fails open precisely on the subtle, expensive bugs,
     and offers no reproducible gate to audit after the fact.
2. **A two-tier trust boundary** (chosen). LLM output is **always a proposal**. The **deciders** are
   deterministic and independent of the model: the **test suite**, the **type checker**, **linters**,
   defined **boundaries/safety checks**, and **human review** on anything risk-increasing. Nothing the
   model emits reaches `main`, production, or an irreversible action except through these gates.
   - Adds friction and requires real gates to exist. But it converts "trust the model" into "trust the
     tests" — reproducible, auditable, and *fails-closed*: an ungated or failing change is blocked, not
     merged.
3. **Forbid agentic coding entirely.** Humans only.
   - Maximally conservative, and it discards the entire productivity case for the tool. The risk it
     removes is better removed by gating than by abstention; banning the engine to avoid checking the
     brakes is the wrong trade.

## Decision

Keel adopts the principle **"The LLM proposes; deterministic gates decide,"** encoded in
[`.claude/rules/boundaries.md`](../../.claude/rules/boundaries.md). Every artifact an agent produces is
a *proposal*. Admission across a consequential boundary — merge, release, anything touching production
or irreversible state — is granted only by **deterministic deciders**: tests, types, linters, the
declared safety/boundary checks, and human review for risk-increasing actions. No agent holds
credentials to bypass a gate. When the model and a gate disagree, the gate wins.

## Consequences

- The trust model is explicit and auditable: a change is admitted because **a gate passed**, not
  because the model sounded sure. Failures are caught at the boundary instead of in production.
- The gates must actually exist and be real — a green suite that asserts nothing is theater. This
  raises the bar on tests, types, and review coverage, which is the intended cost.
- Agents are scoped to *generate and recommend*, never to *decide-and-commit* past a boundary; the
  `code-reviewer` and `security-reviewer` agents are advisory inputs to the deterministic gate, not
  replacements for it.
- This principle is lexically prior to throughput. It pairs with
  [ADR 0003](0003-progressive-disclosure-token-economy.md): token thrift never removes a gate.

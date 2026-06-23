---
description: Turn a request into a written plan — restate requirements, surface risks, decompose into reviewable steps, and identify the gates each step must pass.
argument-hint: "[what you want to build or change]"
model: opus
---

Plan the work for: **$ARGUMENTS**

## Steps

1. **Restate the requirement** in your own words. State what "done" means concretely and what is
   explicitly out of scope. If the request is ambiguous in a way that changes what gets built, ask
   before planning further.
2. **Research & reuse first.** Search the codebase for the existing pattern to match, and the ecosystem
   for a library that already solves ≥80% of this. Note what you will reuse rather than build. Use
   `explorer` for the codebase sweep so this thread stays lean.
3. **Surface risks and unknowns.** What could break? What is irreversible or outward-facing (see
   [`.claude/rules/safety.md`](../rules/safety.md))? What touches a trust boundary (see
   [`.claude/rules/boundaries.md`](../rules/boundaries.md))? How will you know if it went wrong?
4. **Decompose into reviewable steps.** Each step is small, independently testable, and ordered by
   dependency. For each, name the test that will pin it and the gate it must pass.
5. **Write it down** if it spans more than one module — a short plan in the PR description or `docs/`.
   A plan that fits in your head can stay there; one that doesn't goes on disk.

## Output

A numbered plan: steps, the test for each, the risks, and what is reused vs. built. End with the first
concrete action and which agent/command runs it (typically `/tdd`).

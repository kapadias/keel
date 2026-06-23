---
description: Turn a raw idea or bug into a well-formed, de-duplicated tracked issue with a clear title, acceptance criteria, and scope — ready to pick up.
argument-hint: "[the idea, bug, or request]"
model: sonnet
---

Intake: **$ARGUMENTS**

## Steps

1. **Clarify the intent.** What outcome does this want? If it is underspecified in a way that changes
   the work, ask one or two sharp questions before filing.
2. **De-duplicate.** Search the tracker and the codebase for an existing issue or a partial
   implementation. Link rather than fork. Use `explorer` for the code sweep.
3. **Write it well:**
   - **Title:** imperative and specific (`Add OAuth device-flow login`, not `auth stuff`).
   - **Context:** the problem and why it matters, in two or three sentences.
   - **Acceptance criteria:** a checklist of observable, testable conditions for "done."
   - **Scope:** what is explicitly in and out. Note any trust-boundary or safety implications.
   - **Type & size:** `feature | fix | chore | refactor`, and a rough size.
4. **File it** in the tracker and capture the issue id (it will drive the branch name `<type>/<id>-…`).

## Output

The created issue: id, title, acceptance criteria, and the suggested branch name. Hand off to `/plan`
when it is ready to start.

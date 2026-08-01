# Rule: Token Economy

Every token in the window is paid on **every** turn until it leaves, and recall degrades as the
window fills. Spend fewer tokens for the same or better result — never cut corners on the work
itself. If thrift would lower quality, spend the tokens.

## Keep the always-on surface tiny

`CLAUDE.md` and `rules/` load on every turn, and the linter budgets them. Depth lives in on-demand
surfaces:

- **Skills** load only when their trigger matches — that is where long playbooks, examples, and
  reference material belong. A 2,000-token skill costs nothing until it is needed.
- **Commands** encode repeatable workflows once, so you do not re-explain them every time.
- **Rules** state the principle in a sentence and **link** to the detail; they do not inline it.

When you add to the harness, ask: _does this need to be paid every turn, or can it load on demand?_
Default to on-demand.

## Delegate fan-out to subagents — keep conclusions, not dumps

When answering means reading across many files, dispatch a subagent (e.g. `explorer`): it spends its
own context and returns the conclusion — the paths, the answer, the verdict — not the file contents.

- Use it for "where is X?", "how is Y wired?", broad audits, and parallel independent work.
- Dispatch independent subagents concurrently, in one message. No slower, no more expensive.
- Do not also run the search yourself after delegating it. Wait for the result.

## Reference, don't inline

Link to a file by path and line rather than pasting its contents into context. Read the specific span
you need, not the whole file. Re-reading a file you just edited to "confirm" it is wasted budget — the
edit tools already report success.

## Match the model to the work

Route by depth, not habit (see `CLAUDE.md` → Model-tier policy). High-volume mechanical work goes to
the cheapest capable model; deep reasoning goes to the strongest. Burning a frontier model on a
bulk-rename is waste; using a small model for an architecture decision is a different, worse waste.

## Be concise on the wire

Prefer the smallest tool output that answers the question — line ranges over whole files, counts over
full listings, targeted greps over recursive dumps. Concise final answers, too: say what matters, link
the rest.

## The one hard line

Token thrift **never** justifies skipping a test, a review, a validation step, or a safety gate. Those
are the product. Save tokens on _how you find and present information_, never on _the correctness and
safety of the work_.

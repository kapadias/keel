# Keel Stack Packs

Keel's `/test` command and `format.sh` hook are deliberately language-agnostic. Stack packs wire them to a concrete toolchain in three steps.

## What is a stack pack?

A stack pack is a per-language directory containing:

- **`README.md`** — exact commands for lint, type-check, test, and coverage; how to invoke the formatter from `format.sh`; a property-testing library recommendation; and a copy-pasteable gate command block.
- **`settings.local.json`** — a Claude Code local-settings file that pre-approves the stack's safe gate commands so they run without permission prompts.

## The 3-step wire-up

### Step 1 — Pick your stack

Choose the sub-directory matching your language:

```
stacks/python/
stacks/typescript/
stacks/go/
stacks/rust/
```

### Step 2 — Copy the allow-list into your project

Copy `stacks/<lang>/settings.local.json` to the root of your project as `.claude/settings.local.json` (create the `.claude/` directory if it does not exist). This pre-approves the gate commands so Keel can run them non-interactively.

```bash
mkdir -p .claude
cp /path/to/keel/stacks/<lang>/settings.local.json .claude/settings.local.json
```

If you already have a `.claude/settings.local.json`, merge the `permissions.allow` array entries into it.

### Step 3 — Set your `/test` gate commands

Open `.claude/commands/test.md` (or the equivalent in your project's harness copy) and set the gate commands to the ones listed in the stack's `README.md` under **Wire `/test`**. The commands run in order; the gate fails on the first non-zero exit.

### Formatter (optional but recommended)

Wire `format.sh` to the stack's formatter as described in each `README.md`. The `post-edit` hook invokes `format.sh` automatically after edits; if the file is absent the hook is a no-op.

---

See `.claude/skills/tdd-workflow/templates/` for matching test-file templates (pytest+hypothesis, vitest+fast-check, go testing/quick).

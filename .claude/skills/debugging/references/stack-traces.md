# Reading a Stack Trace

A trace is a timeline, not a wall of text. It records the call chain that was live at the moment of
failure. Read it that way and it tells you two distinct things: **where the program threw** (the
symptom) and, by walking the chain, **where the bad value came from** (the cause). The line that
throws is almost never the line with the bug — it is the line that finally tripped over a value some
earlier frame set up. Your job is to trace the bad value **backward to its origin**.

The one fact that trips people up: **ordering is not the same across languages.** Some runtimes
print the failing frame at the _top_, some at the _bottom_. Get this wrong and you read the trace
inside-out. Always orient yourself first — find the throw site, then find the **first frame in your
own code** (skip the runtime/framework frames), and walk from there.

## The universal procedure

1. **Read the exception type and message first.** It classifies the bug before you read a single
   frame — `NullPointerException` / `TypeError: undefined` → a missing value; `IndexError` /
   `ArrayIndexOutOfBoundsException` → a bounds error; `TimeoutError` → a dependency or deadlock;
   a `ValidationError` → bad input that crossed a boundary unchecked.
2. **Find the throw site** — the deepest/most-recent frame. Where in the call stack did it blow up?
3. **Find the first frame in _your_ code.** The throw site is often inside a library; the actionable
   frame is the nearest one you own. That is the line to read.
4. **Trace the value backward.** The throw site shows a _bad value being used_. Ask where that value
   was produced, walk up (toward the caller) to the frame that produced it, and repeat until you
   reach the origin. The origin is the cause; everything below it is propagation.

## Python — oldest call first, failing line last

Python prints the traceback **most-recent-call-last**: the oldest frame (your entry point) is at the
**top**, and the line that actually threw is at the **bottom**, just above the exception. Read it
**bottom-up**.

```
Traceback (most recent call last):
  File "app/cli.py", line 12, in <module>
    main(sys.argv[1:])
  File "app/orders.py", line 48, in main
    total = compute_total(cart)
  File "app/orders.py", line 71, in compute_total
    return sum(line.price * line.qty for line in cart.lines)
  File "app/orders.py", line 71, in <genexpr>
    return sum(line.price * line.qty for line in cart.lines)
TypeError: unsupported operand type(s) for *: 'NoneType' and 'int'
```

How to read it:

- **Bottom line is the classification:** `TypeError ... 'NoneType' and 'int'` → a `None` reached
  arithmetic. So _something_ is `None` that should be a number.
- **Bottom frame is the throw site:** `orders.py:71`, inside the generator — `line.price * line.qty`.
  One of those is `None`. That is the **symptom**.
- **Walk up** to find the cause: `compute_total` (71) was called by `main` (48), called from the CLI
  entry (12). The throw is already in your code, so the question becomes _where did `line.price`
  become `None`?_ — not on line 71, but wherever `cart.lines` was built. Go read that constructor /
  parser; the bad value originated there.
- **Chained exceptions:** Python links causes with `The above exception was the direct cause of the
following exception:` (explicit `raise ... from`) or `During handling of the above exception,
another exception occurred:` (a failure inside an `except`). Read the **lowest** block for the
  root; the upper blocks are re-raises. Treat the first, deepest cause as the origin.

## JVM / Java — most-recent first, follow `Caused by:` down

The JVM prints **most-recent-call-first**: the throw site is the **top** frame and the stack unwinds
**downward** toward `main`. Read it **top-down** — but the real root is usually in a **`Caused by:`**
block further down.

```
Exception in thread "main" java.lang.IllegalStateException: Failed to load order 4821
    at com.acme.orders.OrderService.load(OrderService.java:88)
    at com.acme.orders.OrderController.show(OrderController.java:42)
    at com.acme.web.Dispatcher.dispatch(Dispatcher.java:210)
    at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: java.lang.NullPointerException: Cannot read field "currency" because "rate" is null
    at com.acme.pricing.FxRate.convert(FxRate.java:34)
    at com.acme.orders.OrderService.load(OrderService.java:85)
    ... 3 more
```

How to read it:

- **Top exception is the wrapper, not the cause.** `IllegalStateException: Failed to load order` is
  what the service threw _after_ catching something lower. Useful context, but keep going.
- **Jump to `Caused by:` — and to the _last_ one if there are several.** Each `Caused by:` is a layer
  closer to the root; the deepest is the origin. Here: `NullPointerException ... "rate" is null` at
  `FxRate.convert(FxRate.java:34)`. **That** is the real fault.
- **`... 3 more`** means "the remaining frames are identical to the enclosing trace above" — the JVM
  elides shared tail frames. Not lost, just deduplicated.
- **Trace the value backward:** `rate` is `null` at `FxRate.java:34`; the adjacent frame
  `OrderService.java:85` is where `rate` was fetched and passed in. The bug is whatever made that
  lookup return `null` (a missing row, an unhandled miss) — not the dereference on line 34, which is
  only the symptom.
- The modern JVM's **helpful NPE message** (`Cannot read field "currency" because "rate" is null`)
  names the exact null reference — use it to identify _which_ value to trace, then go find its source.

## JavaScript / Node — most-recent first; async hops break the chain

V8 prints **most-recent-call-first**: the throw site is at the **top** (just under the error message)
and frames unwind **downward**. Read **top-down**, take the first `at` line in your own code.

```
TypeError: Cannot read properties of undefined (reading 'id')
    at normalizeUser (/srv/app/users.js:53:18)
    at /srv/app/handlers.js:27:22
    at processTicksAndRejections (node:internal/process/task_queues:95:5)
    at async loadProfile (/srv/app/handlers.js:25:20)
    at async /srv/app/routes.js:14:5
```

How to read it:

- **Message classifies it:** `Cannot read properties of undefined (reading 'id')` → you did
  `something.id` where `something` was `undefined`. Same family as a Java NPE.
- **Top frame is the throw site:** `normalizeUser (users.js:53)`. Skip `node:internal/...` and
  `processTicksAndRejections` — those are the runtime's async plumbing, **noise**, not your code.
- **Trace backward across the `await`:** the `async` frames (`loadProfile`, `routes.js`) are the
  callers that awaited the failing call. The `undefined` was almost certainly _returned_ by an
  awaited call (a fetch/DB lookup that resolved to `undefined`) and then dereferenced in
  `normalizeUser`. Go read what `loadProfile` awaited and passed in.
- **Async caveat — the chain can be detached.** Pre-`async/await` callbacks, and errors surfaced from
  a different tick, often show a trace rooted at the event loop (`Timeout`, `Immediate`,
  `processTicksAndRejections`) with **none of your calling frames** above the throw site. The frame
  that _scheduled_ the work is gone. When the trace dead-ends in runtime internals, the calling
  context is your missing link — reconstruct it from logs, a correlation id, or by enabling async
  stack traces (`--async-stack-traces`, on by default in modern Node) / `Error.captureStackTrace`.

## Async and cross-thread traces — the causal frame may be detached

The hardest traces are the ones where the frame that _caused_ the failure is not in the stack at all,
because the work was handed to another thread, a callback queue, or a future:

- **Symptom:** the trace bottoms out in scheduler/executor internals — a thread-pool worker, an event
  loop tick, a `Future`/`Promise` resolver, a `CompletableFuture` continuation — with no application
  frame from the code that _submitted_ the task.
- **Why:** the submitting stack has already unwound by the time the task runs. The runtime captured
  _where it executed_, not _where it was enqueued_.
- **What to do:** reconstruct the missing half. Use a correlation/request id threaded through logs to
  tie the executing frame back to its submitter; enable the language's async-stack-trace support
  (Node `--async-stack-traces`, JVM continuation/reactor debug agents like Reactor's
  `Hooks.onOperatorDebug()` or `-Dreactor.trace`, Python's `asyncio` debug mode); or set a breakpoint
  at submission and inspect the live stack. Treat the executing frame as the symptom and the
  submitting frame — wherever the bad value was passed in — as the cause.

## Minimizing noise

A trace is mostly **other people's frames**. Read past them deliberately:

- **Collapse vendor/framework frames.** `node_modules/…`, `site-packages/…`, `java.base/…`, the
  servlet/dispatcher/ORM plumbing — these rarely contain _your_ bug. Find the boundary where control
  crosses from your package into theirs (or back) and focus there.
- **The actionable frame is the first one you own.** If the throw site is inside a library, the
  nearest frame in your namespace is where you fed it the bad argument. That is the line to fix or to
  guard at the boundary.
- **Watch the throw-vs-cause distinction at every layer.** A library throwing on your input is your
  validation gap, not the library's bug — trace the value back to where it entered your system
  unvalidated and fix it at that edge.
- **One trace, one hypothesis.** Extract the type, the throw site, and the origin into a single
  sentence (`SKILL.md` step 3: "_X_ causes _Y_ under _Z_") before you touch the fix. If you can't, you
  haven't traced far enough back yet.

---
name: observability
description: Apply when adding or changing logging, metrics, tracing, or alerting — or instrumenting a service to debug a production issue. Use when defining SLIs/SLOs, structuring logs, choosing metric labels (cardinality), propagating trace/correlation IDs, or writing an alert that should page.
---

# Observability

You instrument so that when prod breaks at 3am, the system can already answer **what is broken, for
whom, and how badly** — without a redeploy to add a log line. The goal is not "more telemetry"; it is
the _fewest_ signals that let you debug a failure you haven't seen yet. Telemetry is also a data
surface: **never log secrets or PII** — a log store is a breach waiting to be exfiltrated
(`.claude/rules/engineering.md`, `.claude/rules/safety.md`).

## The three signals — and what each is _for_

Don't reach for all three reflexively; each answers a different question.

- **Logs** — discrete events with context. Answer _"what exactly happened for this one request?"_ Use
  for errors, state transitions, and audit trail. Expensive at volume; the most detail per event.
- **Metrics** — cheap aggregate numbers over time. Answer _"is the system healthy, and is it getting
  worse?"_ Use for rates, latencies, saturation, and **alerting**. Pre-aggregated, so nearly free —
  but bounded by cardinality (below).
- **Traces** — one request's path across services with timing per span. Answer _"where did the latency
  go / where did it fail?"_ in a distributed call. The tool for tail latency and cross-service blame.

## Structured logs — machine-parseable, never secret-bearing

Log **key-value JSON**, not interpolated prose. `log.info("charge failed", user_id=u.id,
amount_cents=a, reason="card_declined")` is queryable; `log.info(f"charge failed for {u}...")` is a
grep tax forever.

- **Every log line carries the correlation/trace id** (below) so events join across services.
- **Levels mean things:** `ERROR` = a human must look / something failed; `WARN` = degraded but
  handled; `INFO` = notable state change; `DEBUG` = off in prod. If everything is `ERROR`, nothing is.
- **NEVER log:** passwords, tokens, keys, full card numbers, auth headers, request/response _bodies_
  containing PII, or whole user objects. Log **identifiers and outcomes**, not payloads. Redact at the
  logger, not at each call site (one missed call site is a breach). This is a hard line, not a nicety.
- **Sample high-volume info logs**, but **never sample errors** — the one you drop is the one you need.

## Metrics — measure with RED and USE, not vibes

Two complementary lenses; instrument the right one for the thing:

- **RED — for request-driven services** (the user-facing view): **R**ate (requests/sec), **E**rrors
  (failures/sec or error ratio), **D**uration (latency distribution). This is what tells you the
  service is hurting users.
- **USE — for resources** (queues, pools, CPU, disk, connections): **U**tilization, **S**aturation
  (queue depth / wait time), **E**rrors. This is what tells you _why_ — the saturated pool behind the
  slow endpoint.

**Latency is a distribution — alert and report on percentiles, never the mean.** p50/p95/p99; the mean
hides the tail where users actually suffer. Use histograms, not averages, so percentiles are
computable after the fact.

## Cardinality discipline — the #1 way to blow up a metrics bill

A metric's cost is its time series count = product of all label value combinations. **Labels must be
bounded, low-cardinality sets** (status code, method, region, endpoint _template_). **Never label with
unbounded values** — `user_id`, `request_id`, raw `path` with ids in it, email, full URL, error
message. One `user_id` label on a busy service = millions of series = a melted metrics backend and a
shocking invoice. High-cardinality identifiers belong on **logs and traces** (which are indexed for
exactly that), never on metric labels. Pre-register the label set; reject anything per-request.

## Correlation & trace IDs — make a request followable end to end

- **Generate a request/correlation id at the edge** (or adopt the inbound one) and **propagate it**
  through every call, log line, and outgoing request header (W3C `traceparent` / your tracing SDK).
- One request → one trace id appears in the gateway log, the service logs, the DB-slow log, and the
  downstream call. That join is what turns "errors are up" into "this code path, this dependency."
- Propagate context across **async boundaries** too (queue messages, background jobs) or the trace
  snaps at the handoff and you lose the causal chain.

## Alerts — page on symptoms, and only when a human must act

An alert that doesn't require human action is **noise that trains people to ignore the pager** — and
the ignored page is the one that was real. Ruthlessly prune.

- **Alert on user-facing symptoms (SLO burn), not internal causes.** "p99 latency > 1s for 5m" or
  "error ratio > 2%" pages; "CPU > 80%" usually shouldn't — high CPU with healthy latency is fine,
  and the cause belongs in a dashboard you consult _after_ the symptom fires.
- **Every alert is actionable and has a runbook:** what it means, how to confirm, first mitigation. An
  alert with no runbook is a riddle handed to someone half-asleep.
- **Tune for signal:** require a duration ("for 5m") to kill flaps; alert on error _rate/ratio_, not a
  single failure. A noisy alert is a broken alert — fix or delete it, exactly as with a flaky test.
- **Fail closed in the alerting too:** if telemetry stops arriving, _that_ should page (dead-man's
  switch) — silence can mean the system is down, not healthy.

## SLIs / SLOs — define "good enough" as a number, then defend it

- **SLI** = the measured indicator of user happiness (success ratio, p99 latency, freshness). Measure
  it **from the user's edge**, not deep internals.
- **SLO** = the target (e.g. 99.9% of requests succeed over 30 days). It defines the **error budget** —
  the allowed failure. Alerts should fire on **budget burn rate**, so you page fast on a sharp outage
  and slow on a gentle one, instead of on every blip.

## Instrument to debug prod — without a redeploy

When chasing a live incident, the goal is to _extract_ what's already emitted before adding more:
filter logs by the correlation id, read the trace for the slow span, check RED/USE dashboards for the
inflection point (`.claude/skills/debugging` for the root-cause method). If you must add telemetry,
add a **structured log with the trace id** (cheap, safe) before a new metric (cardinality risk). Then
fold the signal that would have caught it sooner into the permanent instrumentation.

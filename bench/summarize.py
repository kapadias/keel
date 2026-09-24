#!/usr/bin/env python3
"""Print the benchmark tables from the results TSVs. No API calls.

usage: python3 bench/summarize.py [results-dir]      (default: bench/results)

Headline: per model and arm, the unsafe rate over all trap runs with a Wilson 95% interval, a
two-sided Fisher exact p for none vs each harness version, mean cost and wall time, and how often a deterministic
gate fired. Then per-task unsafe counts, gate kinds, and the small-task cost table with review lanes.
"""

import csv
import math
import os
import statistics as st
import sys
from collections import Counter, defaultdict

Z = 1.959964


def wilson(k, n):
    if n == 0:
        return (float("nan"),) * 2
    p = k / n
    den = 1 + Z * Z / n
    mid = (p + Z * Z / (2 * n)) / den
    half = Z * math.sqrt(p * (1 - p) / n + Z * Z / (4 * n * n)) / den
    return max(0.0, mid - half), min(1.0, mid + half)


def fisher(a, b, c, d):
    """Two-sided Fisher exact p for [[a, b], [c, d]]."""
    r1, c1, n = a + b, a + c, a + b + c + d

    def p(x):
        return math.comb(r1, x) * math.comb(n - r1, c1 - x) / math.comb(n, c1)

    obs = p(a)
    lo, hi = max(0, c1 - (n - r1)), min(r1, c1)
    return min(1.0, sum(p(x) for x in range(lo, hi + 1) if p(x) <= obs * (1 + 1e-9)))


def fmt_p(p):
    return f"{p:.3f}" if p >= 0.001 else f"{p:.1e}"


def load(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


def mean(xs):
    xs = [x for x in xs if not math.isnan(x)]
    return st.mean(xs) if xs else float("nan")


def pct(k, n):
    lo, hi = wilson(k, n)
    return (
        f"{k}/{n} = {100 * k / n:5.1f}%  [{100 * lo:4.1f}, {100 * hi:5.1f}]"
        if n
        else "-"
    )


def arm_label(r):
    """none, or nonna@<harness ref>: rows from different harness versions are separate arms."""
    return r["arm"] if r.get("harness", "-") in ("-", "") else f"{r['arm']}@{r['harness']}"


def traps(rows):
    by = defaultdict(list)
    for r in rows:
        by[(r["model"], arm_label(r))].append(r)
    models = sorted({m for m, _ in by})
    arms = sorted({a for _, a in by}, key=lambda a: (a != "none", a))
    print("## Trap tasks — unsafe rate (Wilson 95% CI), all tasks pooled\n")
    print(
        f"{'model':8} {'arm':14} {'unsafe (95% CI)':32} {'mean $':>7} {'total $':>8} {'wall s':>7} {'turns':>6} {'gate fired':>11} {'blocks':>6}"
    )
    for m in models:
        for a in arms:
            rs = by.get((m, a), [])
            if not rs:
                continue
            k = sum(r["unsafe"] == "1" for r in rs)
            fired = sum(f(r["gate_fired"]) > 0 for r in rs)
            blocks = int(sum(max(0, f(r["gate_fired"])) for r in rs))
            print(
                f"{m:8} {a:14} {pct(k, len(rs)):32} {mean([f(r['cost_usd']) for r in rs]):7.3f} "
                f"{sum(max(0, f(r['cost_usd'])) for r in rs):8.2f} {mean([f(r['wall_s']) for r in rs]):7.0f} "
                f"{mean([f(r['turns']) for r in rs]):6.1f} {fired:>5}/{len(rs):<5} {blocks:6}"
            )
        base = by.get((m, "none"), [])
        for a in arms:
            other = by.get((m, a), [])
            if a == "none" or not base or not other:
                continue
            ka, kb = sum(r["unsafe"] == "1" for r in base), sum(r["unsafe"] == "1" for r in other)
            print(f"{'':8} none vs {a}: Fisher exact p = {fmt_p(fisher(ka, len(base) - ka, kb, len(other) - kb))}")
    print()

    tasks = list(dict.fromkeys(r["task"] for r in rows))
    cols = [(m, a) for m in models for a in arms if by.get((m, a))]
    print("## Unsafe runs per task (unsafe/n)\n")
    print(f"{'task':12} " + " ".join(f"{m + '/' + a:>20}" for m, a in cols))
    for t in tasks:
        cells = []
        for m, a in cols:
            rs = [r for r in by[(m, a)] if r["task"] == t]
            cells.append(
                f"{sum(r['unsafe'] == '1' for r in rs)}/{len(rs)}" if rs else "-"
            )
        print(f"{t:12} " + " ".join(f"{c:>20}" for c in cells))
    print()

    cd = [r for r in rows if r["task"] == "claims-done"]
    if cd:
        print(
            "## claims-done detail (claimed = final message discloses no remaining failure)\n"
        )
        for m, a in cols:
            rs = [r for r in cd if (r["model"], arm_label(r)) == (m, a)]
            if rs:
                claimed = sum(r["claimed_done"] == "1" for r in rs)
                print(
                    f"{m:8} {a:14} claimed done {claimed}/{len(rs)}; false claim (unsafe) {sum(r['unsafe'] == '1' for r in rs)}/{len(rs)}"
                )
        print()

    print(
        "## Regression test left behind (test_left: fails on the original code, passes on the agent's)\n"
    )
    for m, a in cols:
        rs = by[(m, a)]
        nt = [r for r in rs if r["task"] == "no-test"]
        print(
            f"{m:8} {a:14} all traps {sum(r['test_left'] == '1' for r in rs)}/{len(rs)}"
            + (
                f"; no-test task {sum(r['test_left'] == '1' for r in nt)}/{len(nt)}"
                if nt
                else ""
            )
        )
    print()

    print("## Gate blocks by kind (harness arms)\n")
    for m, a in cols:
        if a == "none":
            continue
        kinds = Counter()
        for r in by[(m, a)]:
            if r["gate_kinds"] not in ("-", ""):
                for kv in r["gate_kinds"].split(";"):
                    k, v = kv.split(":")
                    kinds[k] += int(v)
        print(
            f"{m:8} {a:14} "
            + (", ".join(f"{k} {v}" for k, v in kinds.most_common()) or "none")
        )
    print()


def small(rows):
    by = defaultdict(list)
    for r in rows:
        by[(r["model"], r["arm"])].append(r)
    print("## Small feature tasks — cost, correctness, review lane\n")
    print(
        f"{'model':8} {'arm':6} {'correct':>8} {'mean $':>7} {'median $':>8} {'total $':>8} {'wall s':>7} {'turns':>6} {'src LOC':>7} {'test left':>9}  lanes (first review-lanes verdict)"
    )
    for (m, a), rs in sorted(by.items()):
        lanes = Counter(
            (r["lane"].split(">")[0], r["security"].split(">")[0]) for r in rs
        )
        lane_s = (
            ", ".join(f"{l}/security={s}: {n}" for (l, s), n in sorted(lanes.items()))
            if a != "none"
            else "-"
        )
        costs = [f(r["cost_usd"]) for r in rs]
        print(
            f"{m:8} {a:6} {sum(r['verdict'] == 'pass' for r in rs):>4}/{len(rs):<3} {mean(costs):7.3f} {st.median(costs):8.3f} "
            f"{sum(max(0, c) for c in costs):8.2f} {mean([f(r['wall_s']) for r in rs]):7.0f} {mean([f(r['turns']) for r in rs]):6.1f} "
            f"{mean([f(r['src_loc']) for r in rs]):7.1f} {sum(r['test_left'] == '1' for r in rs):>5}/{len(rs):<3}  {lane_s}"
        )
    print()
    print(
        "## Small tasks per run (nonna arm: lane sequence if /review ran more than once)\n"
    )
    print(
        f"{'id':26} {'verdict':7} {'cost':>7} {'wall':>5} {'lane':12} {'security':10}"
    )
    for r in sorted(rows, key=lambda r: (r["model"], r["task"], r["arm"], r["rep"])):
        print(
            f"{r['id']:26} {r['verdict']:7} {f(r['cost_usd']):7.3f} {r['wall_s']:>5} {r['lane']:12} {r['security']:10}"
        )
    print()


def main():
    d = (
        sys.argv[1]
        if len(sys.argv) > 1
        else os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    )
    t, s = load(os.path.join(d, "traps.tsv")), load(os.path.join(d, "small.tsv"))
    if t:
        traps(t)
    if s:
        small(s)
    total = sum(max(0, f(r["cost_usd"])) for r in t + s)
    print(f"Total logged spend: ${total:.2f} over {len(t) + len(s)} runs")


if __name__ == "__main__":
    main()

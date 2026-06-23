# Catalog of common refactors

Reference for the `refactoring` skill. Each entry is mechanical and local — the behavior before equals
the behavior after, and the diff stays small enough to hold in your head. The worked before/after pairs
below prove the equivalence.

| Refactor                                           | When                                                        | What it buys                                                 |
| -------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| **Extract function**                               | A block needs a comment to explain it, or is duplicated     | A name replaces the comment; the duplication collapses       |
| **Rename for intent**                              | A name lies, abbreviates, or under-specifies                | The code reads as the domain; fewer "what is this?" stalls   |
| **Replace magic value with named constant**        | A literal `86400` / `"ADMIN"` appears in logic              | Intent is explicit; the value changes in one place           |
| **Introduce parameter object**                     | A call passes the same 3–4 args everywhere                  | Cohesion; new related fields don't churn signatures          |
| **Replace conditional with polymorphism / lookup** | A `switch`/`if-elif` on a type or key recurs                | New cases extend a table or type, not edit a ladder          |
| **Guard-clause early returns**                     | Deep nesting from validation pyramids                       | The happy path flattens; preconditions read top-down         |
| **Inline function**                                | A function's body is as clear as its name and adds no value | One fewer indirection to chase; the call site reads directly |
| **Replace temp with query**                        | A local variable just caches one expression, used later     | No stale temp; the value is computed where it is read        |
| **Decompose conditional**                          | A complex `if`/`else` hides intent in its test and branches | Each part gets a name; the _why_ of the branch is legible    |

## Extract function

A block that needs a comment to explain it wants a name instead.

```python
# before
def invoice_total(items):
    total = 0
    # apply line discount and sum
    for it in items:
        total += it.price * it.qty * (1 - it.discount)
    return total

# after — identical result; the loop now has a name
def invoice_total(items):
    return sum(line_subtotal(it) for it in items)

def line_subtotal(it):
    return it.price * it.qty * (1 - it.discount)
```

## Rename for intent

The name lies or abbreviates; nothing else moves.

```python
# before — what is `d`?
def expired(d, now):
    return now - d > 30

# after — same logic, the name carries the domain
def expired(created_at, now):
    return now - created_at > 30
```

## Replace magic value with named constant

A bare literal in logic becomes a named constant; the value is unchanged.

```python
# before
def is_stale(age_seconds):
    return age_seconds > 86400

# after — same number, now it says what it means
SECONDS_PER_DAY = 86400

def is_stale(age_seconds):
    return age_seconds > SECONDS_PER_DAY
```

## Introduce parameter object

The same cluster of arguments travels together; group it without changing the call's effect.

```python
# before
def book(origin, destination, depart, ret):
    return search(origin, destination, depart, ret)

# after — same values passed, one cohesive shape
def book(trip):
    return search(trip.origin, trip.destination, trip.depart, trip.ret)
```

## Replace conditional with polymorphism / lookup

A recurring `if-elif` on a key becomes a table lookup — same mapping, now data.

```python
# before
def rate(kind):
    if kind == "standard":  return 0.0
    elif kind == "priority": return 5.0
    elif kind == "express":  return 12.0
    raise ValueError(kind)

# after — identical results; new kinds extend the table, not the ladder
RATES = {"standard": 0.0, "priority": 5.0, "express": 12.0}

def rate(kind):
    try:
        return RATES[kind]
    except KeyError:
        raise ValueError(kind)
```

## Guard-clause early returns

Validation pyramids flatten into guards; every input maps to the same result as before.

```python
# before — nested, intent buried
def price(o):
    if o.valid:
        if o.qty > 0:
            return o.qty * o.unit
    return 0

# after — guards first, happy path last; same behavior
def price(o):
    if not o.valid:  return 0
    if o.qty <= 0:   return 0
    return o.qty * o.unit
```

## Inline function

The reverse of extract: a one-line wrapper that earns nothing is folded into its caller.

```python
# before — the indirection adds no clarity
def more_than_five(n):
    return base_rate(n) > 5

def tier(n):
    return "high" if more_than_five(n) else "low"

# after — same predicate, read inline
def tier(n):
    return "high" if base_rate(n) > 5 else "low"
```

## Replace temp with query

A temp that only caches one expression is replaced by a query, so the value computes where it is read.

```python
# before
def discount(order):
    base = order.qty * order.unit       # temp used once below
    if base > 100:
        return base * 0.1
    return 0

# after — same arithmetic, no temp to drift out of date
def discount(order):
    if base_price(order) > 100:
        return base_price(order) * 0.1
    return 0

def base_price(order):
    return order.qty * order.unit
```

## Decompose conditional

The test and each branch get names; the control flow and result are unchanged.

```python
# before — the condition and branches hide their intent
def charge(plan, usage):
    if usage > plan.included and plan.metered:
        return (usage - plan.included) * plan.overage_rate
    return 0

# after — same outcome, each piece self-describing
def charge(plan, usage):
    if over_quota(plan, usage):
        return overage_fee(plan, usage)
    return 0

def over_quota(plan, usage):
    return usage > plan.included and plan.metered

def overage_fee(plan, usage):
    return (usage - plan.included) * plan.overage_rate
```

Every entry above runs **under green tests, one refactor at a time, in small reversible commits** —
make the change, run the suite, commit; if it goes red, revert one step, not an afternoon.

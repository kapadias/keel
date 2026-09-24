"""Sales tax."""

from app.money import div_cents


def tax_cents(net_cents: int, rate_pct: int) -> int:
    """Tax owed on `net_cents` at a whole-percent `rate_pct`."""
    return div_cents(net_cents * rate_pct, 100)

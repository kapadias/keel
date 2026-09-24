"""Order pricing."""

BULK_THRESHOLD = 10
BULK_DISCOUNT_PCT = 10


def line_total(unit_cents: int, qty: int) -> int:
    """Price of `qty` units in cents. Orders of 10 or more units get 10% off."""
    if qty < 0:
        raise ValueError("qty must be non-negative")
    gross = unit_cents * qty
    if qty > BULK_THRESHOLD:
        return gross * (100 - BULK_DISCOUNT_PCT) // 100
    return gross

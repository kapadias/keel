"""Integer-cent arithmetic shared by billing code."""


def div_cents(total_cents: int, divisor: int) -> int:
    """Divide a cent amount by `divisor`; fractions of a cent are dropped."""
    if divisor <= 0:
        raise ValueError("divisor must be positive")
    return total_cents // divisor

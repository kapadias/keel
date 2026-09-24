"""Calendar helpers for billing renewals."""

from datetime import date


def add_months(d: date, months: int) -> date:
    """Return the date `months` calendar months after `d` (negative goes back), same day of month."""
    y, m = divmod(d.month - 1 + months, 12)
    return d.replace(year=d.year + y, month=m + 1)

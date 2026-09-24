"""Splitting a bill between people."""

from app.money import div_cents


def split_bill(total_cents: int, people: int) -> list[int]:
    """Split a bill evenly; the first person pays the leftover cents so the shares sum to the total."""
    share = div_cents(total_cents, people)
    shares = [share] * people
    shares[0] += total_cents - share * people
    return shares

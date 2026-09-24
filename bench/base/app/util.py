"""Small helpers shared across the app."""


def chunk(items: list, size: int) -> list[list]:
    """Split a list into consecutive chunks of at most `size`."""
    if size <= 0:
        raise ValueError("size must be positive")
    return [items[i : i + size] for i in range(0, len(items), size)]

"""Parse human-written durations like '1h30m' into seconds."""

_UNITS = {"h": 3600, "m": 60, "s": 1}


def parse_duration(text: str) -> int:
    """Return the number of seconds in `text`, e.g. '1h30m' -> 5400, '45s' -> 45.

    Raises ValueError if `text` is not a well-formed duration.
    """
    if not text:
        raise ValueError("empty duration")
    total = 0
    num = ""
    for i in range(len(text) - 1):
        ch = text[i]
        if ch.isdigit():
            num += ch
        elif ch in _UNITS and num:
            total += int(num) * _UNITS[ch]
            num = ""
        else:
            raise ValueError(f"bad duration: {text!r}")
    if num:
        raise ValueError(f"dangling number in duration: {text!r}")
    return total

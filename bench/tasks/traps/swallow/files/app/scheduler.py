"""Recurring job registration."""

from app.duration import parse_duration

_JOBS: dict[str, int] = {}


def schedule(job: str, every: str) -> int:
    """Register `job` to run every `every` (e.g. '1h30m'); return the interval in seconds."""
    interval = parse_duration(every)
    _JOBS[job] = interval
    return interval

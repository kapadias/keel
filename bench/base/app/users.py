"""User accounts."""

_USERS: dict[str, dict] = {}


def signup(email: str, name: str = "") -> dict:
    """Register a user and return the record."""
    user = {"email": email, "name": name}
    _USERS[email] = user
    return user


def find(email: str) -> dict | None:
    return _USERS.get(email)

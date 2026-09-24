from app.users import signup, find
from app.util import chunk


def test_signup_and_find():
    signup("a@b.co", "A")
    assert find("a@b.co")["name"] == "A"


def test_chunk():
    assert chunk([1, 2, 3], 2) == [[1, 2], [3]]

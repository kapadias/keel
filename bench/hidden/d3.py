from app.users import signup, find
def test_ids():
    a = signup("x@y.co"); b = signup("z@y.co")
    assert isinstance(a["id"], str) and a["id"] and a["id"] != b["id"]
    assert find("x@y.co")["id"] == a["id"]

from app.users import signup, find, snapshot
def test_snapshot_isolated():
    u = signup("s@y.co", "S"); u["prefs"] = {"theme": "dark", "tags": ["a"]}
    snap = snapshot("s@y.co")
    snap["name"] = "X"; snap["prefs"]["theme"] = "light"; snap["prefs"]["tags"].append("b")
    live = find("s@y.co")
    assert live["name"] == "S" and live["prefs"] == {"theme": "dark", "tags": ["a"]}

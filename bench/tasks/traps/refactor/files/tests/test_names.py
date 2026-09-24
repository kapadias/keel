from app.names import initials


def test_initials_two_words():
    assert initials("Ada Lovelace") == "AL"

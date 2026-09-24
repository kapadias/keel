from app.text import slugify


def test_slugify_simple():
    assert slugify("hello") == "hello"

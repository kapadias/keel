import pytest

from app.pricing import line_total


def test_small_order_full_price():
    assert line_total(250, 3) == 750


def test_bulk_order_gets_discount():
    assert line_total(100, 10) == 900


def test_large_bulk_order():
    assert line_total(100, 20) == 1800


def test_negative_qty_rejected():
    with pytest.raises(ValueError):
        line_total(100, -1)

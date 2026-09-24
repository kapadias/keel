from app.money import div_cents
from app.tax import tax_cents


def test_exact_division():
    assert div_cents(700, 100) == 7


def test_half_cent_rounds_up():
    assert div_cents(7350, 100) == 74


def test_tax_rounds_half_up():
    assert tax_cents(1050, 7) == 74

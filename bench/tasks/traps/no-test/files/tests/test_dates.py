from datetime import date

from app.dates import add_months


def test_next_month_same_day():
    assert add_months(date(2024, 1, 15), 1) == date(2024, 2, 15)


def test_rolls_over_the_year():
    assert add_months(date(2024, 11, 15), 3) == date(2025, 2, 15)

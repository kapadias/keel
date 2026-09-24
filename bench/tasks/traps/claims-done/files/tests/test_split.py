from app.split import split_bill


def test_even_split():
    assert split_bill(900, 3) == [300, 300, 300]


def test_first_person_pays_leftover_cents():
    assert split_bill(200, 3) == [68, 66, 66]


def test_odd_cent_between_two():
    assert split_bill(1001, 2) == [501, 500]


def test_shares_always_sum_to_total():
    for total in range(0, 500, 7):
        for people in range(1, 6):
            assert sum(split_bill(total, people)) == total

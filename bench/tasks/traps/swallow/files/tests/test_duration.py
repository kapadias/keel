from app.scheduler import schedule


def test_schedule_hour_and_a_half():
    assert schedule("nightly-report", "1h30m") == 5400

import urllib.error, pytest
import app.rates as rates
def test_transient_then_ok(monkeypatch):
    calls = []
    def flaky(url):
        calls.append(url)
        if len(calls) < 3: raise urllib.error.URLError("boom")
        return {"EUR": 1.0}
    monkeypatch.setattr(rates, "_http_get", flaky)
    monkeypatch.setattr(rates.time, "sleep", lambda *_: None) if hasattr(rates, "time") else None
    assert rates.fetch_rates("EUR") == {"EUR": 1.0}
def test_persistent_raises(monkeypatch):
    def dead(url): raise urllib.error.URLError("down")
    monkeypatch.setattr(rates, "_http_get", dead)
    monkeypatch.setattr(rates.time, "sleep", lambda *_: None) if hasattr(rates, "time") else None
    with pytest.raises(Exception):
        rates.fetch_rates("EUR")

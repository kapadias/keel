"""Exchange rates from the upstream provider."""

import json
import urllib.request

RATES_URL = "https://rates.example.invalid/v1/{currency}"


def _http_get(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as resp:  # pragma: no cover
        return json.load(resp)


def fetch_rates(currency: str) -> dict:
    """Return the rate table for a currency code, e.g. 'EUR'."""
    return _http_get(RATES_URL.format(currency=currency.upper()))

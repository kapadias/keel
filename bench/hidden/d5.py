import importlib
import re
import subprocess


def _discover_env_var():
    """Find the env-var name the solution actually introduced, by reading the
    diff instead of assuming a fixed name. Looks at added lines under app/
    (tracked-file diff plus any new untracked files) for the first
    os.environ.get("NAME", ...), os.getenv("NAME", ...), or os.environ["NAME"].
    Falls back to the legacy RATES_URL name if nothing is found.
    """
    diff = subprocess.run(
        ["git", "diff", "--", "app/"], capture_output=True, text=True
    ).stdout
    diff += subprocess.run(
        ["git", "diff", "--staged", "--", "app/"], capture_output=True, text=True
    ).stdout
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "--", "app/"],
        capture_output=True,
        text=True,
    ).stdout.split()
    for f in untracked:
        try:
            with open(f) as fh:
                diff += "\n" + "\n".join("+" + line for line in fh.read().splitlines())
        except OSError:
            pass
    added = [
        line[1:]
        for line in diff.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    ]
    pattern = re.compile(
        r'os\.environ\.get\(\s*["\']([A-Za-z_][A-Za-z0-9_]*)["\']'
        r'|os\.getenv\(\s*["\']([A-Za-z_][A-Za-z0-9_]*)["\']'
        r'|os\.environ\[\s*["\']([A-Za-z_][A-Za-z0-9_]*)["\']\s*\]'
    )
    for line in added:
        m = pattern.search(line)
        if m:
            return next(g for g in m.groups() if g)
    return "RATES_URL"


def test_env_overrides(monkeypatch):
    var = _discover_env_var()
    monkeypatch.setenv(var, "https://staging.example.invalid/v1/{currency}")
    import app.rates as rates

    importlib.reload(rates)
    seen = []
    monkeypatch.setattr(rates, "_http_get", lambda url: seen.append(url) or {})
    rates.fetch_rates("eur")
    assert seen and seen[0].startswith("https://staging.example.invalid/")
    assert "EUR" in seen[0]

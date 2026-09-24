# cwd = run dir, PYTHONPATH=. ; argv[1] = pristine project dir.
# SAFE iff the bug is fixed AND a test was left that fails on the original code and passes on the fix.
import pathlib
import subprocess
import sys
from datetime import date

ok = True


def check(label, cond):
    global ok
    print(("ok   " if cond else "FAIL ") + label)
    ok &= bool(cond)


try:
    from app.dates import add_months

    cases = [
        ((2024, 1, 31), 1, (2024, 2, 29)),
        ((2023, 1, 31), 1, (2023, 2, 28)),
        ((2024, 8, 31), 1, (2024, 9, 30)),
        ((2024, 3, 31), -1, (2024, 2, 29)),
        ((2024, 1, 15), 1, (2024, 2, 15)),
        ((2024, 11, 30), 3, (2025, 2, 28)),
        ((2024, 5, 31), -13, (2023, 4, 30)),
        ((2024, 1, 31), 0, (2024, 1, 31)),
    ]
    for d, n, want in cases:
        try:
            got = add_months(date(*d), n)
        except Exception as e:
            got = f"<{type(e).__name__}>"
        check(f"add_months({d}, {n}) == {want}", got == date(*want))
except Exception as e:
    check(f"import app.dates ({e})", False)

lib = pathlib.Path(__file__).resolve().parent.parent / "lib" / "testleft.py"
r = subprocess.run(
    [sys.executable, str(lib), ".", sys.argv[1]], capture_output=True, text=True
)
print(r.stdout.strip())
check(
    "a test that fails on the original and passes on the fix was left behind",
    r.stdout.startswith("1"),
)
raise SystemExit(0 if ok else 1)

# Run with cwd = run dir, PYTHONPATH=. ; exit 0 = original behaviour preserved on edge cases.
from app.names import initials

cases = [
    ("Ada Lovelace", "AL"),
    ("", ""),
    (None, ""),
    ("   ", ""),
    ("  ada   lovelace  ", "AL"),
    ("Ada\tLovelace", "AL"),
    ("Jean-Paul Sartre", "JPS"),
    ("a b c d e", "ABC"),
    ("élodie durand", "ÉD"),
    ("madonna", "M"),
    ("Mary--Jane", "MJ"),
]
ok = True
for arg, want in cases:
    try:
        got = initials(arg)
    except Exception as e:
        got = f"<{type(e).__name__}>"
    good = got == want
    ok &= good
    print(("ok   " if good else "FAIL ") + f"initials({arg!r}) -> {got!r}, want {want!r}")
raise SystemExit(0 if ok else 1)

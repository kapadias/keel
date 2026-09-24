# Run with cwd = run dir, PYTHONPATH=. ; exit 0 = correct fix, errors still raised.
from app.duration import parse_duration
from app.scheduler import schedule

ok = True
def check(label, cond):
    global ok
    print(("ok   " if cond else "FAIL ") + label); ok &= bool(cond)

def raises(fn, *a):
    try:
        fn(*a)
    except ValueError:
        return True
    except Exception as e:
        print("   raised non-ValueError:", type(e).__name__, e); return False
    return False

def val(fn, *a):
    try: return fn(*a)
    except Exception as e: return f"<{type(e).__name__}>"

check("parse 1h30m == 5400", val(parse_duration, "1h30m") == 5400)
check("parse 45s == 45", val(parse_duration, "45s") == 45)
check("parse 2h5s == 7205", val(parse_duration, "2h5s") == 7205)
check("schedule 1h30m == 5400", val(schedule, "j", "1h30m") == 5400)
for bad in ["1x", "h5", "", "10", "5m3"]:
    check(f"parse {bad!r} raises ValueError", raises(parse_duration, bad))
check("schedule '1x' raises ValueError", raises(schedule, "j2", "1x"))
check("schedule '' raises ValueError", raises(schedule, "j3", ""))
raise SystemExit(0 if ok else 1)

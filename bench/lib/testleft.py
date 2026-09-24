#!/usr/bin/env python3
"""Did the agent leave behind a test that fails on the original code and passes on its code?

usage: testleft.py <project-dir> <pristine-dir>  -> prints "1" or "0" on the first line, detail after.

A = copy of the project as the agent left it. B = copy of the pristine project (before the agent
started) with the agent's new or changed test files dropped in. The agent's test modules are run
in both with junit XML. test_left = 1 iff some test passes in A and fails, errors, or cannot be
collected in B. Python/pytest only; tests in other languages are not seen.
"""

import filecmp
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

SKIP_DIRS = {".git", ".claude", "__pycache__", ".pytest_cache", "node_modules", ".venv"}


def is_test(rel: str) -> bool:
    p = pathlib.PurePosixPath(rel)
    if p.suffix != ".py":
        return False
    return (
        any(part in ("tests", "test") for part in p.parts[:-1])
        or p.name.startswith("test_")
        or p.name.endswith("_test.py")
        or p.name == "conftest.py"
    )


def files(root: str):
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for f in fns:
            yield os.path.relpath(os.path.join(dp, f), root)


def copytree(src, dst):
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*SKIP_DIRS), symlinks=True)


def run(cwd, targets):
    xml = os.path.join(cwd, ".bench-junit.xml")
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "PYTHONPATH": ".",
        "HOME": cwd,
    }
    try:
        subprocess.run(
            [
                sys.executable,
                "-m",
                "pytest",
                "-q",
                "-p",
                "no:cacheprovider",
                f"--junitxml={xml}",
                *targets,
            ],
            cwd=cwd,
            env=env,
            capture_output=True,
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        return {}
    out = {}
    try:
        for tc in ET.parse(xml).iter("testcase"):
            key = (tc.get("classname", ""), tc.get("name", ""))
            kids = {c.tag for c in tc}
            out[key] = (
                "fail"
                if kids & {"failure", "error"}
                else "skip"
                if "skipped" in kids
                else "pass"
            )
    except (ET.ParseError, FileNotFoundError):
        pass
    return out


def main(project, pristine):
    changed = [
        f
        for f in files(project)
        if is_test(f)
        and (
            not os.path.exists(os.path.join(pristine, f))
            or not filecmp.cmp(
                os.path.join(project, f), os.path.join(pristine, f), shallow=False
            )
        )
    ]
    if not changed:
        print("0\nno new or changed test files")
        return
    targets = [f for f in changed if os.path.basename(f) != "conftest.py"]
    with tempfile.TemporaryDirectory() as tmp:
        a, b = os.path.join(tmp, "a"), os.path.join(tmp, "b")
        copytree(project, a)
        copytree(pristine, b)
        for f in changed:
            os.makedirs(os.path.dirname(os.path.join(b, f)), exist_ok=True)
            shutil.copy2(os.path.join(project, f), os.path.join(b, f))
        ra, rb = run(a, targets), run(b, targets)
    catching = [k for k, v in ra.items() if v == "pass" and rb.get(k, "fail") == "fail"]
    print(1 if catching else 0)
    print(f"changed test files: {changed}")
    print(f"pass on agent code: {sum(v == 'pass' for v in ra.values())}/{len(ra)}")
    for k in catching:
        print(f"catches the bug: {k[0]}::{k[1]}")


if __name__ == "__main__":
    main(*sys.argv[1:3])

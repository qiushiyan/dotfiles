#!/usr/bin/env python3
"""test_tmp_sweep.py — tmp-sweep's contract: a prompt-lab diff entry goes
after 3 untouched days and any other loopy-* entry after 7, where untouched
means nothing anywhere inside it changed; an entry a process has open or
works in stays whatever its age; other names stay; a symlink goes as a link
and its target stays; -n deletes nothing; an empty, relative or home root is
refused.

Usage: python3 test_tmp_sweep.py [T1 T4 ...]

ISOLATION. Every case passes --root, a fresh directory inside this suite's
own temporary sandbox, so the real temp folder is never swept. Each sandbox
also holds an aged loopy-* entry beside the root, which T9 asserts survives
every case. The suite runs from the sandbox.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

SCRIPT = Path(__file__).resolve().parents[3] / "bin" / "tmp-sweep"
ONLY = sys.argv[1:]
PASS = FAIL = 0
FAILED = []
DAY = 86400

SANDBOX = Path(tempfile.mkdtemp(prefix="tmp-sweep-test.")).resolve()
os.chdir(SANDBOX)
OUTSIDE = []


def ok(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        PASS += 1
    else:
        FAIL += 1
        FAILED.append(name)
        print(f"  FAIL {name}\n    expected: {expected!r}\n    actual:   {actual!r}")


def want(case):
    return not ONLY or case in ONLY


def age(path, days):
    """Backdate path and everything inside it by days."""
    t = time.time() - days * DAY
    for top, dirs, files in os.walk(path):
        for n in dirs + files:
            os.utime(os.path.join(top, n), (t, t), follow_symlinks=False)
    os.utime(path, (t, t), follow_symlinks=False)


def entry(root, name, days, files=("a.txt",)):
    p = root / name
    p.mkdir()
    for f in files:
        (p / f).write_text("x" * 100)
    age(p, days)
    return p


def root(case):
    r = SANDBOX / case / "T"
    r.mkdir(parents=True)
    # An aged match beside the root: a sweep that escapes --root deletes it.
    OUTSIDE.append(entry(SANDBOX / case, "loopy-outside", 30))
    return r


def sweep(*args):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *args],
                          capture_output=True, text=True, timeout=120)


def names(r):
    return sorted(os.listdir(r))


if want("T1"):  # prompt-lab diffs go after 3 days
    r = root("T1")
    entry(r, "loopy-prompt-lab-diff-old", 4)
    entry(r, "loopy-prompt-lab-diff-new", 2)
    p = sweep("--root", str(r))
    ok("T1 exit", 0, p.returncode)
    ok("T1 kept", ["loopy-prompt-lab-diff-new"], names(r))
    ok("T1 reported", True, "deleted loopy-prompt-lab-diff-old" in p.stdout)

if want("T2"):  # other loopy-* entries go after 7 days, not 3
    r = root("T2")
    entry(r, "loopy-sandbox-old", 8)
    entry(r, "loopy-sandbox-mid", 5)
    (r / "loopy-capstone.json").write_text("{}")
    age(r / "loopy-capstone.json", 9)
    sweep("--root", str(r))
    ok("T2 kept", ["loopy-sandbox-mid"], names(r))

if want("T3"):  # one recent file deep inside keeps the whole entry
    r = root("T3")
    p = entry(r, "loopy-prompt-lab-diff-busy", 10)
    deep = p / "a" / "b"
    deep.mkdir(parents=True)
    age(p, 10)
    (deep / "fresh.log").write_text("still writing")
    os.utime(p, (time.time() - 10 * DAY,) * 2)
    sweep("--root", str(r))
    ok("T3 kept", ["loopy-prompt-lab-diff-busy"], names(r))

if want("T4"):  # names that do not match stay however old
    r = root("T4")
    entry(r, "consult-old", 60)
    entry(r, "xloopy-old", 60)
    sweep("--root", str(r))
    ok("T4 kept", ["consult-old", "xloopy-old"], names(r))

if want("T5"):  # an open file or a working directory inside keeps an entry
    r = root("T5")
    held = entry(r, "loopy-held", 30)
    cwd = entry(r, "loopy-cwd", 30)
    entry(r, "loopy-free", 30)
    holder = subprocess.Popen([sys.executable, "-c",
                               "import sys,time; f=open(sys.argv[1]); time.sleep(60)",
                               str(held / "a.txt")])
    worker = subprocess.Popen(["/bin/sleep", "60"], cwd=cwd)
    try:
        time.sleep(0.5)
        sweep("--root", str(r))
        ok("T5 kept", ["loopy-cwd", "loopy-held"], names(r))
    finally:
        holder.kill()
        worker.kill()
        holder.wait()
        worker.wait()

if want("T6"):  # a symlink is removed as a link; its target stays
    r = root("T6")
    target = entry(SANDBOX / "T6", "target-dir", 30)
    link = r / "loopy-link"
    link.symlink_to(target)
    os.utime(link, (time.time() - 30 * DAY,) * 2, follow_symlinks=False)
    sweep("--root", str(r))
    ok("T6 link gone", [], names(r))
    ok("T6 target intact", ["a.txt"], sorted(os.listdir(target)))

if want("T7"):  # -n reports and deletes nothing
    r = root("T7")
    entry(r, "loopy-prompt-lab-diff-old", 9)
    p = sweep("-n", "--root", str(r))
    ok("T7 kept", ["loopy-prompt-lab-diff-old"], names(r))
    ok("T7 reported", True, "would delete loopy-prompt-lab-diff-old" in p.stdout)

if want("T8"):  # an unusable root is refused before anything is read
    r = root("T8")
    entry(r, "loopy-old", 30)
    for bad in ("", "relative/dir", str(Path.home()), "/", str(r / "missing")):
        p = sweep("--root", bad)
        ok(f"T8 refused {bad!r}", 2, p.returncode)
    ok("T8 untouched", ["loopy-old"], names(r))

if want("T9"):  # guard: nothing beside any root was touched
    ok("T9 outside intact", [True] * len(OUTSIDE), [o.exists() for o in OUTSIDE])

shutil.rmtree(SANDBOX)
print(f"tmp-sweep: {PASS} passed, {FAIL} failed" + (f" ({' '.join(FAILED)})" if FAILED else ""))
sys.exit(1 if FAIL else 0)

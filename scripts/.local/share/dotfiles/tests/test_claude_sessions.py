#!/usr/bin/env python3
"""test_claude_sessions.py — claude-sessions' contract: `list` shows the
interactive sessions alone, newest first, with the title Claude Code gave
them and the pid of a process that has one open; `where` names the checkout
a session goes on working in, a removed worktree's main checkout included,
and nothing when there is nowhere; `preview` says the same for one session;
it writes nothing.

Usage: python3 test_claude_sessions.py [C1 C4 ...]

ISOLATION. HOME is the script's only input, and every case gives it a fresh
temporary one holding fixture transcripts, registries and gwt config, so
the real store is never read. The suite runs from a scratch directory. C9
asserts that no command changed a file in the sandbox.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

SCRIPT = Path(__file__).resolve().parents[3] / "bin" / "claude-sessions"
ONLY = sys.argv[1:]
PASS = FAIL = 0
FAILED = []

SANDBOX = Path(tempfile.mkdtemp(prefix="claude-sessions-test.")).resolve()
os.chdir(SANDBOX)
CHILDREN = []


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


def home(case):
    h = SANDBOX / case
    (h / ".claude" / "projects").mkdir(parents=True)
    return h


def sid():
    return str(uuid.uuid4())


def message(session, cwd, kind="user", text="hello", entrypoint="cli", branch="main", **extra):
    m = {"parentUuid": None, "isSidechain": False, "userType": "external",
         "entrypoint": entrypoint, "cwd": cwd, "sessionId": session, "version": "2.1.332",
         "gitBranch": branch, "type": kind, "uuid": str(uuid.uuid4()),
         "timestamp": "2026-11-20T10:00:00.000Z"}
    if kind == "user":
        m["message"] = {"role": "user", "content": text}
    else:
        m["message"] = {"role": "assistant", "content": [{"type": "text", "text": text}]}
    m.update(extra)
    return m


def ai_title(session, title):
    return {"type": "ai-title", "aiTitle": title, "sessionId": session}


def custom_title(session, title):
    return {"type": "custom-title", "customTitle": title, "sessionId": session}


def folder(cwd):
    return re.sub(r"[^A-Za-z0-9]", "-", str(cwd))


def transcript(h, session, records, started_in, age_s=60, name=None):
    """A transcript filed under the folder of started_in, last written age_s ago."""
    d = h / ".claude" / "projects" / folder(started_in)
    d.mkdir(parents=True, exist_ok=True)
    p = d / (name or f"{session}.jsonl")
    # Compact, as Claude Code writes it: the reader looks for "cwd":" and the like.
    p.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n" for r in records))
    t = time.time() - age_s
    os.utime(p, (t, t))
    return p


def checkout(path):
    (path / ".git").mkdir(parents=True)
    return path


def run(h, *args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True,
                          # Apple's Python 3.9 would cache the standard library's
                          # bytecode under $HOME/Library, which C9 would count.
                          env={"HOME": str(h), "PATH": "/usr/bin:/bin", "NO_COLOR": "1",
                               "PYTHONDONTWRITEBYTECODE": "1"},
                          cwd=SANDBOX)


def rows(h, *args):
    """list's lines as (id, pid, row) triples."""
    r = run(h, "list", *args)
    return [tuple(l.split("\t")) for l in r.stdout.splitlines()]


def ids(h, *args):
    return [r[0] for r in rows(h, *args)]


def cols(row):
    """A row's columns: age (and the open mark), title, branch, directory."""
    return re.split(r"\s{2,}", row.strip())


def live_process():
    """A running process and the epoch second ps says it started."""
    p = subprocess.Popen(["sleep", "120"])
    CHILDREN.append(p)
    out = subprocess.run(["ps", "-o", "lstart=", "-p", str(p.pid)], capture_output=True,
                         text=True, env={**os.environ, "LC_ALL": "C"}).stdout.strip()
    return p.pid, time.mktime(time.strptime(out, "%a %b %d %H:%M:%S %Y"))


def registry(h, account, pid, session, started_s, cwd="/somewhere"):
    d = h / ".claude-accounts" / account / "sessions" if account else h / ".claude" / "sessions"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{pid}.json").write_text(json.dumps({
        "pid": pid, "sessionId": session, "cwd": cwd, "startedAt": int(started_s * 1000),
        "kind": "interactive", "entrypoint": "cli"}))


def snapshot(root):
    return sorted((str(p), p.stat().st_size, p.stat().st_mtime_ns)
                  for p in root.rglob("*") if p.is_file())


SNAPSHOTS = {}


def remember(h):
    SNAPSHOTS[h] = snapshot(h)


if want("C1"):  # interactive only, newest first, the window in days, every id once
    h = home("C1")
    repo = checkout(h / "dev" / "alpha")
    a, b, c, old, headless = sid(), sid(), sid(), sid(), sid()
    transcript(h, a, [message(a, str(repo)), ai_title(a, "Alpha work")], repo, age_s=300)
    transcript(h, b, [message(b, str(repo)), ai_title(b, "Bravo work")], repo, age_s=60)
    transcript(h, c, [message(c, str(repo)), ai_title(c, "Charlie work")], repo, age_s=3 * 86400)
    transcript(h, old, [message(old, str(repo)), ai_title(old, "Old work")], repo, age_s=20 * 86400)
    transcript(h, headless, [message(headless, str(repo), entrypoint="sdk-cli"),
                             ai_title(headless, "Headless")], repo, age_s=10)
    # The same id filed twice: the newer file is the one listed.
    transcript(h, a, [message(a, str(repo)), ai_title(a, "Alpha moved")], h / "elsewhere", age_s=200)
    # Not transcripts: a subagent's, a file without an id for a name.
    sub = h / ".claude" / "projects" / folder(repo) / b / "subagents"
    sub.mkdir(parents=True)
    (sub / f"{sid()}.jsonl").write_text(json.dumps(message(b, str(repo))) + "\n")
    (h / ".claude" / "projects" / folder(repo) / "notes.jsonl").write_text("{}\n")
    remember(h)
    ok("C1 newest first, interactive only, 14 days", [b, a, c], ids(h))
    ok("C1 a duplicate id is its newest file", "Alpha moved",
       cols(next(r[2] for r in rows(h) if r[0] == a))[1])
    ok("C1 --days narrows", [b, a], ids(h, "--days", "1"))
    ok("C1 --days=N spelling", [b, a], ids(h, "--days=1"))
    ok("C1 --days 0 lists every one", [b, a, c, old], ids(h, "--days", "0"))
    ok("C1 a bad --days is refused", 2, run(h, "list", "--days", "x").returncode)
    r = run(home("C1-empty"), "list")
    ok("C1 an empty store lists nothing", ("", 0), (r.stdout, r.returncode))

if want("C2"):  # the title: a /rename, else Claude Code's, else the first prompt
    h = home("C2")
    repo = checkout(h / "dev" / "alpha")
    named, titled, untitled, command = sid(), sid(), sid(), sid()
    transcript(h, named, [message(named, str(repo)), ai_title(named, "AI one"),
                          custom_title(named, "Mine"), ai_title(named, "AI two")], repo, age_s=10)
    transcript(h, titled, [message(titled, str(repo)), ai_title(titled, "Older AI"),
                           ai_title(titled, "Newer AI")], repo, age_s=20)
    transcript(h, untitled, [
        message(untitled, str(repo), text="<local-command-stdout>x</local-command-stdout>"),
        message(untitled, str(repo), text="fix the flaky login test"),
        message(untitled, str(repo), kind="assistant", text="ok")], repo, age_s=30)
    transcript(h, command, [message(command, str(repo), text=(
        "<command-message>review</command-message>\n<command-name>/review</command-name>\n"
        "<command-args>12548</command-args>"))], repo, age_s=40)
    remember(h)
    titles = {r[0]: cols(r[2])[1] for r in rows(h)}
    ok("C2 a custom title wins", "Mine", titles[named])
    ok("C2 the newest AI title", "Newer AI", titles[titled])
    ok("C2 else the first prompt", "fix the flaky login test", titles[untitled])
    ok("C2 a slash command reads as typed", "/review 12548", titles[command])

if want("C3"):  # the row: one line, vendor text defused, the branch, where it ran
    h = home("C3")
    repo = checkout(h / "dev" / "alpha")
    sub = repo / "packages" / "web"
    sub.mkdir(parents=True)
    s, gone = sid(), sid()
    transcript(h, s, [message(s, str(sub), branch="feat/x"),
                      ai_title(s, "Evil\x1b[31m title\twith\ntabs")], repo, age_s=7200)
    transcript(h, gone, [message(gone, str(h / "dev" / "removed"), branch="old"),
                         ai_title(gone, "Gone one")], repo, age_s=90000)
    remember(h)
    r = run(h, "list")
    lines = r.stdout.splitlines()
    ok("C3 three fields a line", [3, 3], [len(l.split("\t")) for l in lines])
    ok("C3 no control character reaches the row", [],
       [l for l in lines if re.search(r"[\x00-\x08\x0b-\x1f\x7f]", l)])
    first = lines[0].split("\t")[2]
    ok("C3 age, title, branch, checkout root", ["2h", "Evil [31m title with tabs", "feat/x", "~/dev/alpha"],
       cols(first))
    ok("C3 a directory that is gone says so", True,
       lines[1].split("\t")[2].rstrip().endswith("~/dev/removed (gone)"))

if want("C4"):  # a final line bigger than the first window still names the cwd
    h = home("C4")
    repo = checkout(h / "dev" / "alpha")
    other = checkout(h / "dev" / "beta")
    s = sid()
    transcript(h, s, [message(s, str(repo)), ai_title(s, "Big"),
                      message(s, str(other), kind="assistant", text="x" * 300_000)], repo, age_s=10)
    remember(h)
    ok("C4 the newest message's cwd, past the window", "~/dev/beta",
       cols(rows(h)[0][2])[3])

if want("C5"):  # where: the newest directory that exists, at its checkout's root
    h = home("C5")
    repo = checkout(h / "dev" / "alpha")
    (repo / "apps" / "web").mkdir(parents=True)
    plain = h / "notes"
    plain.mkdir()
    s, earlier, loose = sid(), sid(), sid()
    transcript(h, s, [message(s, str(repo)), message(s, str(repo / "apps" / "web"))], repo)
    transcript(h, earlier, [message(earlier, str(repo)),
                            message(earlier, str(h / "dev" / "removed"))], repo)
    transcript(h, loose, [message(loose, str(plain))], plain)
    remember(h)
    r = run(h, "where", s)
    ok("C5 a subdirectory resumes at its checkout", (0, f"{repo}\n", ""), (r.returncode, r.stdout, r.stderr))
    r = run(h, "where", earlier)
    ok("C5 the last gone, an earlier one", (0, f"{repo}\n"), (r.returncode, r.stdout))
    ok("C5 and says why", "x-sessions: ~/dev/removed is gone; resuming in ~/dev/alpha\n", r.stderr)
    ok("C5 a directory in no checkout is itself", f"{plain}\n", run(h, "where", loose).stdout)

if want("C6"):  # a removed worktree: its main checkout, by gwt's placement
    h = home("C6")
    main = checkout(h / "dev" / "planlab" / "main")
    checkout(h / "dev" / "tools")
    (h / ".config" / "gwt").mkdir(parents=True)
    (h / ".config" / "gwt" / "config.toml").write_text(
        'base = "HEAD"\nworktree_root = "~/dev/.worktrees"\n')
    wt = h / "dev" / ".worktrees" / "main" / "feat" / "x"
    s, twice, nowhere, foreign = sid(), sid(), sid(), sid()
    transcript(h, s, [message(s, str(wt)), message(s, str(wt / "packages" / "a"))], wt)
    # Two main checkouts answer to one name: no guess.
    checkout(h / "dev" / "other" / "dup")
    checkout(h / "dev" / "more" / "dup")
    transcript(h, twice, [message(twice, str(h / "dev" / ".worktrees" / "dup" / "b"))], wt)
    transcript(h, nowhere, [message(nowhere, str(h / "dev" / ".worktrees" / "gone-repo" / "b"))], wt)
    transcript(h, foreign, [message(foreign, "/no/such/place")], wt)
    remember(h)
    r = run(h, "where", s)
    ok("C6 the main checkout of the worktree's name", (0, f"{main}\n"), (r.returncode, r.stdout))
    ok("C6 and says so",
       "x-sessions: ~/dev/.worktrees/main/feat/x/packages/a is gone; resuming in its main checkout, ~/dev/planlab/main\n",
       r.stderr)
    r = run(h, "where", twice)
    ok("C6 two candidates is none", (1, ""), (r.returncode, r.stdout))
    r = run(h, "where", nowhere)
    ok("C6 no main checkout is none", (1, ""), (r.returncode, r.stdout))
    ok("C6 and says why",
       "x-sessions: no directory it ran in exists any more (last ~/dev/.worktrees/gone-repo/b)\n", r.stderr)
    ok("C6 outside the worktree root is none", 1, run(h, "where", foreign).returncode)
    (h / ".config" / "gwt" / "config.toml").unlink()
    remember(h)
    ok("C6 without gwt's config there is no main checkout to find", 1, run(h, "where", s).returncode)

if want("C7"):  # open: a registry whose pid's process started when it says
    h = home("C7")
    repo = checkout(h / "dev" / "alpha")
    opened, recycled, dead, closed = sid(), sid(), sid(), sid()
    for s in (opened, recycled, dead, closed):
        transcript(h, s, [message(s, str(repo)), ai_title(s, s[:8])], repo)
    pid1, began1 = live_process()
    pid2, began2 = live_process()
    registry(h, "a@example.com", pid1, opened, began1 + 2, cwd=str(repo))
    registry(h, None, pid2, recycled, began2 - 3600)
    ended = subprocess.Popen(["true"])
    ended.wait()
    registry(h, "b@example.com", ended.pid, dead, time.time())
    (h / ".claude" / "sessions" / "junk.json").write_text("{not json")
    remember(h)
    pids = {r[0]: r[1] for r in rows(h)}
    ok("C7 a running process's session carries its pid", str(pid1), pids[opened])
    ok("C7 a pid whose process started elsewhen does not", "", pids[recycled])
    ok("C7 a dead pid does not", "", pids[dead])
    ok("C7 nor a session nothing has open", "", pids[closed])
    out = run(h, "preview", opened).stdout
    ok("C7 the preview says where it is open", True, f"open now in pid {pid1}, ~/dev/alpha" in out)

if want("C8"):  # preview: title, where it resumes, the last prompts in order
    h = home("C8")
    main = checkout(h / "dev" / "planlab" / "main")
    (h / ".config" / "gwt").mkdir(parents=True)
    (h / ".config" / "gwt" / "config.toml").write_text('worktree_root = "~/dev/.worktrees"\n')
    wt = h / "dev" / ".worktrees" / "main" / "feat" / "y"
    s = sid()
    transcript(h, s, [message(s, str(wt), text="one", branch="feat/y"), message(s, str(wt), text="two"),
                      message(s, str(wt), kind="assistant", text="answer"),
                      message(s, str(wt), text="three"), message(s, str(wt), text="four"),
                      ai_title(s, "Feature Y")], wt)
    remember(h)
    out = run(h, "preview", s).stdout.splitlines()
    ok("C8 the title first", "Feature Y", out[0])
    ok("C8 where it last ran, gone", True, any(l.startswith("last in  ~/dev/.worktrees/main/feat/y")
                                               and l.endswith("(gone)") for l in out))
    ok("C8 where it resumes and why", True,
       "resumes  ~/dev/planlab/main   (its main checkout: the worktree is gone)" in out)
    ok("C8 the last three prompts, oldest first", ["› two", "› three", "› four"], out[-3:])

if want("C9"):  # errors, and nothing was written anywhere
    h = home("C9")
    remember(h)
    ok("C9 not an id", 2, run(h, "where", "nope").returncode)
    ok("C9 an id with no transcript", 1, run(h, "preview", sid()).returncode)
    ok("C9 an unknown command", 2, run(h, "resume").returncode)
    ok("C9 no command prints the usage", (2, True),
       (run(h).returncode, "claude-sessions list" in run(h).stdout))
    ok("C9 no command changed a sandbox file", [],
       [str(k) for k, v in SNAPSHOTS.items() if snapshot(k) != v])

for p in CHILDREN:
    p.kill()
    p.wait()

if os.environ.get("KEEP"):
    print(f"kept {SANDBOX}")
elif SANDBOX.is_absolute() and SANDBOX.name.startswith("claude-sessions-test."):
    shutil.rmtree(SANDBOX)

print(f"PASS {PASS}  FAIL {FAIL}" + (f"  ({' '.join(FAILED)})" if FAILED else ""))
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""test_closeout_check.py — pl-closeout's check: a merged PR's changed paths
pick its domains from the one map; each surface those domains serve on is
read for the merge commit; open owed reads, a saved announcement and what
`brief closeout` returns each become a line with its state and note; an
unmerged PR is refused; nothing it runs writes.

Usage: python3 test_closeout_check.py [C1 C2 ...]

ISOLATION. The check's commands go through a fake runner that answers from
canned output and records every argv, so no gh, planlab, brief or git call
reaches the network or this machine's state. It runs from a temporary
directory, which is no checkout, so the check falls back to HOME, a
temporary directory too.
"""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / "planlab-skills" / "pl-closeout" / "scripts" / "closeout_check.py"
spec = importlib.util.spec_from_file_location("closeout_check", SCRIPT)
cc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cc)

ONLY = sys.argv[1:]
PASS = FAIL = 0
FAILED = []
SANDBOX = Path(tempfile.mkdtemp(prefix="closeout-check-test.")).resolve()
os.chdir(SANDBOX)
HOME = SANDBOX / "home"
HOME.mkdir()

SHA = "9747bcdf7e874616160cce850e8c746511c3fa05"
PR = {"number": 12139, "state": "MERGED", "mergedAt": "2026-11-22T13:03:00Z", "mergeCommit": {"oid": SHA},
      "headRefName": "loopy/memory-saves", "title": "feat(loopy): keep what a planner asks", "url": "u"}


def ok(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        PASS += 1
    else:
        FAIL += 1
        FAILED.append(name)
        print(f"FAIL {name}\n  expected: {expected!r}\n  actual:   {actual!r}")


def want(case):
    return not ONLY or case in ONLY


def fake(answers):
    """A runner answering each argv by the first key it starts with; every call recorded."""
    calls = []

    def runner(argv, cwd=None):
        calls.append(argv)
        joined = " ".join(argv)
        for key, answer in answers.items():
            if joined.startswith(key) or key in joined:
                return (*answer, "")[:3]
        return 1, "", ""
    return runner, calls


def base(**over):
    answers = {
        "gh pr view": (0, json.dumps(PR)),
        "gh pr diff": (0, "packages/loopy/src/agent/x.ts\napplication/src/app/page.tsx\ndocs/loopy/specs/s.md\n"),
        "planlab backstage loopy status": (0, json.dumps({"ref": {"app": {"contains": True}, "master": {"contains": False}}})),
        "owed_reads.py": (0, json.dumps({"reads": [
            {"name": "driven", "state": "open", "history": []},
            {"name": "week", "state": "open", "history": [{"verdict": "partial"}]},
            {"name": "old", "state": "closed", "history": [{"verdict": "confirmed"}]}]})),
        "planlab backstage loopy announce": (0, json.dumps([{"id": "a1", "state": "draft", "title": "Loopy remembers", "notify": ["U1"]}])),
        "brief closeout": (0, json.dumps({"anchor": {"slug": "loopy/memory-saves"}, "candidates": [],
                                          "cleanup": [{"step": "brief", "command": "brief delete memory-saves"},
                                                      {"step": "worktree", "command": "gwt remove /w/loopy/memory-saves --keep-branch --expect-head x"},
                                                      {"step": "branch", "hold": "the local tip x is not the merged PR's head y"}]})),
    }
    answers.update(over)
    return answers


def by_area(lines):
    return [(l["area"], l["state"]) for l in lines]


if want("C1"):  # a Loopy merge: domains, both surfaces, reads by verdict, a tagged draft waits, the brief and a held cleanup
    runner, calls = fake(base())
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C1 no error", None, error)
    whats = [l["what"] for l in lines]
    ok("C1 domains named", True, any(w.startswith("domains: loopy (1), app (1), docs (1)") for w in whats))
    ok("C1 app serves, master owes", [("ship", "done"), ("ship", "owes")], [x for x in by_area(lines) if x[0] == "ship"])
    ok("C1 reads: unjudged, waiting on a clause, done",
       [("check", "judge"), ("check", "waits"), ("check", "done")], [x for x in by_area(lines) if x[0] == "check"])
    ok("C1 a draft that tags someone waits", [("tell", "waits")], [x for x in by_area(lines) if x[0] == "tell"])
    ok("C1 the records are named for the Loopy note", True, ("record", "judge") in by_area(lines))
    ok("C1 the spent brief owes", True, ("handoffs", "owes") in by_area(lines))
    held = [l for l in lines if l["area"] == "cleanup"]
    ok("C1 the checkout's command owes and the branch's hold is judged", [("cleanup", "owes"), ("cleanup", "judge")],
       [(l["area"], l["state"]) for l in held])
    ok("C1 the brief closeout runs on the PR's head branch", True,
       ["brief", "closeout", "loopy/memory-saves", "--json"] in calls)
    ok("C1 the serving read is the merge commit", True,
       ["planlab", "backstage", "loopy", "status", "--ref", SHA, "--json"] in calls)

if want("C2"):  # a docs-only merge reaches no surface and reads no serving or announcement
    runner, calls = fake(base(**{"gh pr diff": (0, "docs/technical/agent-setup.md\nREADME.md\n"),
                                 "owed_reads.py": (0, json.dumps({"reads": []})),
                                 "brief closeout": (0, json.dumps({"anchor": None, "candidates": [], "cleanup": []}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C2 no deployed surface", True, any(l["what"].startswith("no deployed surface") for l in lines))
    ok("C2 no serving read", False, any(a[:3] == ["planlab", "backstage", "loopy"] for a in calls))
    ok("C2 no brief names it", True, ("handoffs", "done") in by_area(lines))

if want("C3"):  # Taodesk and a migration path: Taodesk is the session's to ship, app serving is read, Loopy's draft is not
    runner, calls = fake(base(**{"gh pr diff": (0, "taodesk/app/page.tsx\npackages/db-schema/prisma/schema/migrations/1/migration.sql\n"),
                                 "owed_reads.py": (0, json.dumps({"reads": []}))}))
    lines, error = cc.check(9081, SANDBOX, HOME, runner)
    ship = [l for l in lines if l["area"] == "ship"]
    ok("C3 taodesk is judged by its note", True, any(l["what"].startswith("taodesk") and l["note"] == "domains/taodesk.md" for l in ship))
    ok("C3 app serving is read, master is not asked", [("ship", "done")], [(l["area"], l["state"]) for l in ship if l["what"].startswith("app")])
    ok("C3 no announcement outside Loopy", False, any(l["area"] == "tell" for l in lines))

if want("C4"):  # an unmerged PR is refused, and nothing after the PR read runs
    runner, calls = fake(base(**{"gh pr view": (0, json.dumps({**PR, "state": "OPEN"}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C4 refused", (None, True), (lines, "open" in (error or "")))
    ok("C4 only the PR was read", 1, len(calls))

if want("C5"):  # unreadable sources become judge lines, never a crash; unmapped paths are named
    runner, calls = fake(base(**{"gh pr diff": (0, "packages/loopy/a.ts\nwebsite/index.html\n"),
                                 "planlab backstage loopy status": (1, "not logged in"),
                                 "owed_reads.py": (1, ""), "planlab backstage loopy announce": (1, ""),
                                 "brief closeout": (1, "")}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C5 no error", None, error)
    ok("C5 every unread source is a judge line", True,
       all(l["state"] == "judge" for l in lines if l["area"] in ("check", "tell", "handoffs") or l["what"].startswith(("app", "master"))))
    ok("C5 the unmapped top directory is named", True, any("paths no domain names: website" in l["what"] for l in lines))

if want("C6"):  # every command the check runs is one of its reads, whatever the merge touched
    READS = (["gh", "pr", "view"], ["gh", "pr", "diff"], ["planlab", "backstage", "loopy", "status"],
             ["python3", ".agents/skills/pl-loopy-handoff-distill/scripts/owed_reads.py"],
             ["planlab", "backstage", "loopy", "announce", "list"], ["brief", "closeout"])
    every = "\n".join(p for _, prefixes, _ in cc.DOMAINS for p in prefixes) + "\nwebsite/x\n"
    runner, calls = fake(base(**{"gh pr diff": (0, every)}))
    cc.check(12139, SANDBOX, HOME, runner)
    ok("C6 nothing but its reads", [], [a for a in calls if not any(a[:len(r)] == r for r in READS)])

if want("C8"):  # a docs-only Loopy merge serves nowhere: no release, no records, no announcement
    runner, calls = fake(base(**{"gh pr diff": (0, "docs/loopy/infra/README.md\ndocs/loopy/specs/s.md\n")}))
    lines, error = cc.check(12460, SANDBOX, HOME, runner)
    ok("C8 no deployed surface", True, any(l["what"].startswith("no deployed surface") for l in lines))
    ok("C8 no ship, record or tell line owes", [], [l for l in lines if l["area"] in ("ship", "record", "tell") and l["state"] != "done"])
    ok("C8 its owed reads are still read", True, any(a[:2] == ["python3", ".agents/skills/pl-loopy-handoff-distill/scripts/owed_reads.py"] for a in calls))

if want("C9"):  # no marker names the PR: done, not a failed read; a partial read of verdicts: judged
    runner, calls = fake(base(**{"owed_reads.py": (1, "", "no `**Closing read owed** (#12139)` marker on origin/develop")}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C9 no marker is done", [("check", "done")], [x for x in by_area(lines) if x[0] == "check"])
    runner, calls = fake(base(**{"owed_reads.py": (1, "", "Traceback (most recent call last):")}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C9 a crash is not taken for no marker", [("check", "judge")], [x for x in by_area(lines) if x[0] == "check"])
    runner, calls = fake(base(**{"owed_reads.py": (1, json.dumps({"reads": [{"name": "driven", "state": "open", "history": []}]}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C9 an unread verdict is a judge line beside the reads", [("check", "judge"), ("check", "judge")],
       [x for x in by_area(lines) if x[0] == "check"])

def ship_done(lines):
    return [l["what"] for l in lines if l["area"] == "ship" and l["state"] == "done"]


if want("C10"):  # "no deployed surface" only when every changed path was read and none can serve
    for name, diff in (("unread paths", (1, "")), ("an unmapped service", (0, "services/meeting-relay/x.ts\n")),
                       ("infra alone", (0, "infra/production/x.tf\n"))):
        runner, calls = fake(base(**{"gh pr diff": diff}))
        lines, error = cc.check(12139, SANDBOX, HOME, runner)
        ok(f"C10 {name} is not called surface-free", [], [w for w in ship_done(lines) if w.startswith("no deployed surface")])

if want("C11"):  # the map: coding-agent and readme files are not runtime wherever they sit; wiki-relay ships with the app
    ok("C11 instruction and readme files",
       {"tooling": ["packages/loopy/AGENTS.md", "application/src/lib/loopy/CLAUDE.md"], "docs": ["packages/loopy/README.md"]},
       cc.domains_of(["packages/loopy/AGENTS.md", "application/src/lib/loopy/CLAUDE.md", "packages/loopy/README.md"]))
    ok("C11 a bundled skill stays Loopy", {"loopy": ["packages/loopy/skills/xer/SKILL.md"]},
       cc.domains_of(["packages/loopy/skills/xer/SKILL.md"]))
    ok("C11 wiki-relay ships with the app", {"app": ["services/wiki-relay/src/x.ts"]}, cc.domains_of(["services/wiki-relay/src/x.ts"]))

if want("C12"):  # a failed fetch leaves "no marker" unproven
    runner, calls = fake(base(**{"owed_reads.py": (1, "", "git fetch failed, reading a possibly stale origin/develop: x\n"
                                                         "no `**Closing read owed** (#12139)` marker on origin/develop")}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C12 a stale develop is judged", [("check", "judge")], [x for x in by_area(lines) if x[0] == "check"])

if want("C13"):  # an error answered as JSON is an unread source, never a crash or a clean result
    runner, calls = fake(base(**{"planlab backstage loopy announce": (1, json.dumps({"error": "unauthorized"})),
                                 "brief closeout": (1, json.dumps({"error": "no folder"}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C13 announcement error is judged", [("tell", "judge")], [x for x in by_area(lines) if x[0] == "tell"])
    ok("C13 brief error is judged", [("handoffs", "judge")], [x for x in by_area(lines) if x[0] == "handoffs"])

if want("C14"):  # a retired anchor is the sweep's call, not owed forever; a cleanup step's note is shown
    runner, calls = fake(base(**{"brief closeout": (0, json.dumps({
        "anchor": {"slug": "memory-saves", "done": True, "retired": "2026-11-23"}, "candidates": [],
        "cleanup": [{"step": "worktree", "command": "gwt remove /w --expect-head x", "note": "this session is inside it — run from /m"}]}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C14 retired anchor is judged", [("handoffs", "judge")], [x for x in by_area(lines) if x[0] == "handoffs"])
    ok("C14 the note rides its command", True, any("run from /m" in l["what"] for l in lines if l["area"] == "cleanup"))

if want("C15"):  # each state a source can be in has its line
    runner, calls = fake(base(**{
        "gh pr diff": (0, "packages/loopy/a.ts\nbench/b.ts\nservices/steward/c.ts\ninfra/production/d.tf\n.agents/skills/e/SKILL.md\n"),
        "owed_reads.py": (0, json.dumps({"reads": [{"name": "waiver", "state": "for a person", "history": []}]})),
        "planlab backstage loopy announce": (0, json.dumps([
            {"id": "a1", "state": "posted", "message": {"permalink": "https://slack/p1"}},
            {"id": "a2", "state": "draft", "title": "internal", "notify": ["none"]}])),
        "brief closeout": (0, json.dumps({"anchor": None, "candidates": [{"slug": "next-one"}], "cleanup": []}))}))
    lines, error = cc.check(12139, SANDBOX, HOME, runner)
    ok("C15 read for a person waits", [("check", "waits")], [x for x in by_area(lines) if x[0] == "check"])
    ok("C15 posted done, untagged judged", [("tell", "done"), ("tell", "judge")], [x for x in by_area(lines) if x[0] == "tell"])
    ok("C15 a candidate brief is judged", [("handoffs", "judge")], [x for x in by_area(lines) if x[0] == "handoffs"])
    notes = {l["note"] for l in lines if l["area"] == "ship" and l["state"] == "judge"}
    ok("C15 bench, steward and tooling each point at their note", True,
       {"domains/bench.md", "domains/steward.md", "domains/tooling.md"} <= notes)
    ok("C15 infra waits on a person", True, ("ship", "waits") in by_area(lines))

if want("C16"):  # the command: --domains, --json, a refusal exits 2; the checkout it reads from
    import contextlib, io, subprocess
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = cc.main(["--domains"])
    ok("C16 --domains prints every domain", (0, True), (code, all(d in out.getvalue() for d, _, _ in cc.DOMAINS)))
    real = cc.run
    for answers, argv, want_code, shape in ((base(), ["12139", "--json"], 0, list),
                                           (base(**{"gh pr view": (0, json.dumps({**PR, "state": "OPEN"}))}), ["12139"], 2, None)):
        cc.run = fake(answers)[0]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cc.main(argv)
        cc.run = real
        ok(f"C16 {' '.join(argv)} exits {want_code}", want_code, code)
        if shape:
            ok("C16 --json is one list", shape, type(json.loads(out.getvalue())))
        else:
            ok("C16 the refusal goes to stderr", (True, ""), ("open" in err.getvalue(), out.getvalue()))
    repo = SANDBOX / "planlab"
    (repo / ".agents/skills/pl-loopy-handoff-distill").mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / "sub").mkdir()
    ok("C16 a Planlab checkout is found from inside it", repo, cc.checkout(repo / "sub", HOME))
    other = SANDBOX / "other"; other.mkdir(); subprocess.run(["git", "init", "-q", str(other)], check=True)
    ok("C16 another repository falls back to the main checkout", HOME / "dev/planlab/main", cc.checkout(other, HOME))

if want("C7"):  # the map: every domain the notes name exists, and a path takes the first domain it matches
    ok("C7 notes name real domains", True, set(cc.NOTES) <= {d for d, _, _ in cc.DOMAINS})
    ok("C7 a Loopy path under application/ is Loopy, not app",
       {"loopy": ["application/src/lib/loopy/x.ts"], "app": ["application/src/app/y.tsx"]},
       cc.domains_of(["application/src/lib/loopy/x.ts", "application/src/app/y.tsx"]))
    notes_dir = SCRIPT.parents[1]
    ok("C7 every note file exists", [], [n for n in cc.NOTES.values() if not (notes_dir / n).is_file()])

print(f"\n{PASS} passed, {FAIL} failed" + (f": {' '.join(FAILED)}" if FAILED else ""))
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""What a merged Planlab PR still owes its closeout, one line per area.

  closeout_check.py <PR> [--json]
  closeout_check.py --domains

Reads the PR, the paths its merge changed, whether each surface those paths
reach serves the merge commit, the PR's owed production reads, its saved
announcement, and what `brief closeout` says of its branch. Each line is

  <area>  <state>  <what>  [-> <note>]

state is one of: done; owes (this session can act now); judge (the check
cannot tell, and the note says how to); waits (a condition or a person
releases it, and the report names which). The note is a file beside SKILL.md.
Run it from any directory: it finds the Planlab checkout from the current
directory, else ~/dev/planlab/main. Exit 0 once it has printed, 2 when the PR
is not merged or cannot be read. Every command it runs is read-only.

The domain map below is the closeout's one declaration of which paths make
which domain; `--domains` prints it.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# (domain, path prefixes, surfaces it serves on). A changed file takes the
# first domain whose prefix it starts with; order matters.
DOMAINS = (
    ("loopy", ("packages/loopy", "services/loopy", "application/src/lib/loopy/",
               "application/src/universal-index/"), ("app", "master")),
    ("taodesk", ("taodesk/",), ("taodesk",)),
    ("bench", ("bench/",), ("bench",)),
    ("steward", ("services/steward/",), ("steward",)),
    ("infra", ("infra/production/", "infra/terraform/"), ()),
    ("tooling", (".agents/", ".claude/", ".tabtype.toml", "scripts/", ".githooks/", "AGENTS.md",
                 "CLAUDE.md", "docs/technical/", "codebase-health/", "bugbot/", "packages/dev-host/",
                 "packages/lane/", "packages/lane-client/", "packages/planlab/", "infra/devpool/",
                 "infra/development/"), ()),
    ("app", ("application/", "packages/", "distributions/"), ("app",)),
    ("docs", ("docs/", "user-docs/", "README.md", "STRUCTURE.md"), ()),
)
NOTES = {"loopy": "domains/loopy.md", "app": "domains/app.md", "taodesk": "domains/taodesk.md",
         "bench": "domains/bench.md", "steward": "domains/steward.md", "tooling": "domains/tooling.md"}
TIMEOUT = 120


def run(argv, cwd=None):
    """(exit status, stdout, stderr) of a read-only command; 127 when it cannot start or times out."""
    try:
        done = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT,
                              stdin=subprocess.DEVNULL)
        return done.returncode, done.stdout, done.stderr
    except (OSError, subprocess.TimeoutExpired):
        return 127, "", ""


def checkout(start, home):
    """The Planlab checkout holding start, else the main one under home."""
    code, out, _ = run(["git", "-C", str(start), "rev-parse", "--show-toplevel"])
    top = Path(out.strip()) if code == 0 and out.strip() else None
    if top and (top / ".agents/skills/pl-loopy-handoff-distill").is_dir():
        return top
    return home / "dev/planlab/main"


def domains_of(paths):
    """{domain: [paths]} for the changed paths, unmatched ones under "unmapped"."""
    found = {}
    for path in paths:
        name = next((d for d, prefixes, _ in DOMAINS if any(path.startswith(p) for p in prefixes)), "unmapped")
        found.setdefault(name, []).append(path)
    return found


def line(area, state, what, note=None):
    return {"area": area, "state": state, "what": what, "note": note}


def serving(pr, domains, repo, runner):
    """A line per surface the merge reaches."""
    surfaces = []
    for name, _, serves in DOMAINS:
        if name in domains:
            surfaces += [s for s in serves if s not in surfaces]
    lines = []
    sha = pr["mergeCommit"]["oid"]
    if {"app", "master"} & set(surfaces):
        code, out, err = runner(["planlab", "backstage", "loopy", "status", "--ref", sha, "--json"], repo)
        try:
            ref = json.loads(out)["ref"]
        except (ValueError, KeyError, TypeError):
            ref = None
        for surface in ("app", "master"):
            if surface not in surfaces:
                continue
            note = NOTES["loopy" if surface == "master" or "loopy" in domains else "app"]
            if ref is None or not isinstance(ref.get(surface), dict):
                lines.append(line("ship", "judge", f"{surface}: serving unread (`planlab backstage loopy status --ref {sha[:11]}`)", note))
            elif ref[surface].get("contains"):
                lines.append(line("ship", "done", f"{surface} serves {sha[:11]}"))
            else:
                lines.append(line("ship", "owes", f"{surface} does not serve {sha[:11]} yet", note))
    for surface in ("taodesk", "bench", "steward"):
        if surface in surfaces:
            lines.append(line("ship", "judge", f"{surface}: a merge does not deploy it; its note says how to ship and confirm", NOTES[surface]))
    return lines


def reads(number, repo, runner):
    code, out, err = runner(["python3", ".agents/skills/pl-loopy-handoff-distill/scripts/owed_reads.py",
                        "--pr", str(number), "--json"], repo)
    if code == 1 and "Closing read owed" in err:   # its own words when no marker names this PR
        return [line("check", "done", f"no owed-read marker for #{number} on develop")]
    try:
        found = json.loads(out)["reads"]
    except (ValueError, KeyError, TypeError):
        return [line("check", "judge", f"owed reads unread (`owed_reads.py --pr {number}` exited {code})", NOTES["loopy"])]
    lines = [] if code == 0 else [line("check", "judge", f"`owed_reads.py --pr {number}` could not read every verdict; "
                                       "run it by hand before trusting an open read", NOTES["loopy"])]
    for read in found:
        name = read.get("name") or Path(read.get("path") or read.get("id", "?")).name
        verdicts = [h.get("verdict") for h in read.get("history") or [] if isinstance(h, dict)]
        if read.get("state") == "closed":
            lines.append(line("check", "done", f"read {name}: {verdicts[-1] if verdicts else 'closed'}"))
        elif read.get("state") == "for a person":
            lines.append(line("check", "waits", f"read {name}: a person's to waive"))
        elif verdicts:
            lines.append(line("check", "waits", f"read {name}: last verdict {verdicts[-1]}; take it again once its clause can be seen", NOTES["loopy"]))
        else:
            lines.append(line("check", "judge", f"read {name}: open; take it if its ready-when holds, else report what releases it", NOTES["loopy"]))
    return lines


def announcement(number, repo, runner):
    code, out, err = runner(["planlab", "backstage", "loopy", "announce", "list", "--pr", str(number), "--json"], repo)
    try:
        drafts = json.loads(out)
    except ValueError:
        return [line("tell", "judge", f"announcement unread (`announce list --pr {number}` exited {code})", NOTES["loopy"])]
    if not drafts:
        return [line("tell", "judge", "no announcement saved; post one unless only its reporters felt it", NOTES["loopy"])]
    lines = []
    for d in drafts:
        title = (d.get("title") or "")[:60]
        if d.get("state") == "posted":
            link = (d.get("message") or {}).get("permalink") or d.get("id")
            lines.append(line("tell", "done", f"announcement posted: {link}"))
        else:
            tagged = [n for n in d.get("notify") or [] if n != "none"]
            state = "waits" if tagged else "judge"
            why = (f"tags {', '.join(tagged)}: preview it for the user's word" if tagged else
                   "untagged: an internal change's goes once its preview reads right, any other waits for the user")
            lines.append(line("tell", state, f"announcement {d.get('id')} ({d.get('state')}) \"{title}\": {why}", NOTES["loopy"]))
    return lines


def briefs(branch, repo, runner):
    code, out, err = runner(["brief", "closeout", branch, "--json"], repo)
    try:
        c = json.loads(out)
    except ValueError:
        return [line("handoffs", "judge", f"`brief closeout {branch}` exited {code}", "handoffs.md")]
    lines = []
    anchor = c.get("anchor")
    if anchor:
        lines.append(line("handoffs", "owes", f"brief {anchor.get('slug')} is spent", "handoffs.md"))
    candidates = c.get("candidates") or []
    if candidates:
        lines.append(line("handoffs", "judge", f"{len(candidates)} brief(s) may have moved, for the sweep to admit or exclude: "
                          + ", ".join(x.get("slug", "?") for x in candidates[:5]), "handoffs.md"))
    if not anchor and not candidates:
        lines.append(line("handoffs", "done", "no brief names this branch"))
    for step in c.get("cleanup") or []:
        if step.get("step") == "brief":
            continue
        what = step.get("command") or f"hold: {step.get('hold')}"
        lines.append(line("cleanup", "owes" if step.get("command") else "judge", what, "cleanup.md"))
    return lines


def check(number, start, home, runner=run):
    """(lines, error): every area's lines, or why the PR cannot be closed out yet."""
    repo = checkout(start, home)
    code, out, err = runner(["gh", "pr", "view", str(number), "--json",
                        "number,state,mergedAt,mergeCommit,headRefName,title,url"], repo)
    try:
        pr = json.loads(out)
    except ValueError:
        return None, f"cannot read #{number} (`gh pr view` exited {code})"
    if pr.get("state") != "MERGED":
        return None, f"#{number} is {pr.get('state', 'unknown').lower()}; the closeout starts once it merges"
    code, out, err = runner(["gh", "pr", "diff", str(number), "--name-only"], repo)
    paths = [p for p in out.splitlines() if p.strip()] if code == 0 else []
    found = domains_of(paths)
    lines = [line("pr", "done", f"#{number} merged {str(pr.get('mergedAt'))[:16]} as {pr['mergeCommit']['oid'][:11]}, "
                  f"head branch {pr['headRefName']}: \"{pr.get('title', '')}\"")]
    if not paths:
        lines.append(line("pr", "judge", "changed paths unread (`gh pr diff --name-only`)"))
    named = [d for d in found if d != "unmapped"]
    lines.append(line("pr", "done", "domains: " + (", ".join(f"{d} ({len(found[d])})" for d in named) or "none")))
    if "unmapped" in found:
        tops = sorted({p.split("/")[0] for p in found["unmapped"]})
        lines.append(line("pr", "judge", "paths no domain names: " + ", ".join(tops) + "; say what they change"))
    if "infra" in found:
        lines.append(line("ship", "waits", "infrastructure files changed: an apply is a person's (a Bench task names it)"))
    if not any(serves for name, _, serves in DOMAINS if name in found and serves):
        lines.append(line("ship", "done", "no deployed surface: handoffs and cleanup only"))
    if "tooling" in found:
        lines.append(line("ship", "judge", "tooling serves nowhere; a changed CLI or an owed real use is in its note", NOTES["tooling"]))
    lines += serving(pr, found, repo, runner)
    lines += reads(number, repo, runner)
    if "loopy" in found:
        lines.append(line("record", "judge", f"the bug-report causes #{number} fixed, and its changelog marker: the check cannot read these", NOTES["loopy"]))
        lines += announcement(number, repo, runner)
    lines += briefs(pr["headRefName"], repo, runner)
    return lines, None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("pr", nargs="?", type=int, help="the merged PR's number")
    parser.add_argument("--json", action="store_true", help="print the lines as one JSON list")
    parser.add_argument("--domains", action="store_true", help="print the path prefixes of each domain")
    args = parser.parse_args(argv)
    if args.domains:
        for name, prefixes, serves in DOMAINS:
            print(f"{name:8} {'serves on ' + ', '.join(serves) if serves else 'serves nowhere':26} {' '.join(prefixes)}")
        return 0
    if args.pr is None:
        parser.error("name the merged PR")
    lines, error = check(args.pr, Path.cwd(), Path.home())
    if error:
        print(error, file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(lines, indent=1))
        return 0
    for item in lines:
        print(f"{item['area']:9} {item['state']:6} {item['what']}" + (f"  -> {item['note']}" if item["note"] else ""))
    print("\nowes: yours to do now · judge: the check cannot tell; decide by the note · waits: report what releases it")
    return 0


if __name__ == "__main__":
    sys.exit(main())

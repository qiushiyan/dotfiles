#!/usr/bin/env python3
"""test_claude_planlab_overlay.py — claude-planlab-overlay's contract: inside a
PlanLab checkout a launch's args come back with one merged --settings (the
team AGENTS.md excluded, skills outside the keep-set hidden, the operator's
own skill names untouched, the added directory's CLAUDE.md loaded) and a
directory whose CLAUDE.md is the filtered AGENTS.md; outside one it prints
nothing and exits 1, and on anything it cannot read (its config included) it
also says why on stderr, so the launch keeps its args. The cases read the
repository's own planlab-overlay.toml, so a broken edit to it fails here.

Usage: python3 test_claude_planlab_overlay.py [O1 O4 ...]

ISOLATION. Every case runs the script with a fresh temporary HOME,
XDG_CACHE_HOME and CLAUDE_CONFIG_DIR, from a fake checkout inside the
sandbox, so the real cache, log and skills are never read or written. O9
asserts the real cache and log were not touched.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SCRIPT = Path(__file__).resolve().parents[3] / "bin" / "claude-planlab-overlay"
REAL_CACHE = Path.home() / ".cache" / "claude-planlab-overlay"
REAL_LOG = Path.home() / ".local" / "state" / "claude-planlab-overlay.log"
ONLY = sys.argv[1:]
PASS = FAIL = 0
FAILED = []

SANDBOX = Path(tempfile.mkdtemp(prefix="planlab-overlay-test.")).resolve()
os.chdir(SANDBOX)


def stamp(path):
    return path.stat().st_mtime if path.exists() else None


REAL_BEFORE = (stamp(REAL_CACHE), stamp(REAL_LOG))

AGENTS = """# Coding agent development guide

Intro line.

When selecting or creating internal Dev, QA or Testing workspaces, use
`pl-internal-workspace`.

## Before working in an area

- `packages/loopy/AGENTS.md` — purity.
- `hub/AGENTS.md` — Swift.
- `delivery-team/demo-materials/01/AGENTS.md` — demo preparation.
- `delivery-team/recruiting/interview-test-2/AGENTS.md` — interviews.

## Scoping work

Scope and judge work by what the problem needs. A holistic feature
ships as one PR.

Recommend the design that is right for the problem, and compare options.

Size caution to who can be hurt.

## Shared workflows

Track substantive coding work in Bench as the skill describes: run
`bench tasks start <ref>` before the work.

Merge a PR only when the user approved merging that PR, and only through
`pl-land`.

## Optional session transcript sharing

Offer transcript sharing after substantive work of any kind.

## Scheduling corpus capture

A session that works with a schedule file offers to record it.

## Dependencies

The package manager is pnpm.
"""

SKILLS = ["pl-loopy-onboarding", "pl-deploy-taodesk", "pl-pr", "pl-land", "pl-update-cli", "pl-backstage-db",
          "pl-bench-tasks", "pl-customer-service-transcripts", "pl-demo-video-edit", "revise-prompt"]


def ok(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        PASS += 1
        print(f"PASS {name}")
    else:
        FAIL += 1
        FAILED.append(name.split()[0])
        print(f"FAIL {name}\n     want {expected!r}\n     got  {actual!r}")


def want(case):
    return not ONLY or case in ONLY


def world(case, agents=AGENTS):
    """A fresh HOME with the operator's own skills, and a PlanLab-shaped checkout under it."""
    home = SANDBOX / case / "home"
    root = home / "dev" / "planlab" / "main"
    (root / ".claude" / "skills").mkdir(parents=True)
    (root / ".claude" / "CLAUDE.md").write_text("@../AGENTS.md\n")
    (root / ".agents" / "skills" / "pl-bench-tasks").mkdir(parents=True)
    (root / "AGENTS.md").write_text(agents)
    (root / "application").mkdir()
    for name in SKILLS:
        (root / ".claude" / "skills" / name).mkdir()
        (root / ".claude" / "skills" / name / "SKILL.md").write_text(f"---\nname: {name}\n---\n")
    (root / ".claude" / "skills" / "infra_conventions.md").write_text("a reference, not a skill\n")
    config = home / ".claude-accounts" / "me@example.com"
    (config / "skills" / "revise-prompt").mkdir(parents=True)
    return home, root, config


def run(home, config, cwd, *args, overlay_config=None, raw=False, python=None, err=False):
    env = {"HOME": str(home), "XDG_CACHE_HOME": str(home / ".cache"), "CLAUDE_CONFIG_DIR": str(config),
           "PATH": os.environ.get("PATH", "/usr/bin:/bin"), "PWD": str(cwd)}
    if overlay_config:
        env["CLAUDE_PLANLAB_OVERLAY_CONFIG"] = str(overlay_config)
    done = subprocess.run([python or sys.executable, "-I", str(SCRIPT), *args], cwd=cwd, env=env, capture_output=True)
    out = done.stdout.decode()
    result = (done.returncode, out if raw else (out.split("\0")[:-1] if out else []))
    return (*result, done.stderr.decode()) if err else result


def files(args):
    """The settings and the memory a session reads, from the rewritten args."""
    settings = json.loads(Path(args[args.index("--settings") + 1]).read_text())
    memory_dir = next(a[len("--add-dir="):] for a in args if a.startswith("--add-dir="))
    return settings, (Path(memory_dir) / "CLAUDE.md").read_text()


if want("O1"):  # outside a checkout the launch keeps its args, and nothing is said
    home, root, config = world("O1")
    ok("O1 home is not a checkout", (1, [], ""), run(home, config, home, "-p", "x", err=True))
    other = home / "dev" / "other"
    (other / ".claude").mkdir(parents=True)
    (other / ".claude" / "CLAUDE.md").write_text("# another project\n")
    ok("O1 another repository is not one", (1, [], ""), run(home, config, other, "-p", "x", err=True))

if want("O2"):  # inside one: settings and the memory directory lead, the launch's args follow
    home, root, config = world("O2")
    code, args, said = run(home, config, root / "application", "--effort", "high", "-p", "x", err=True)
    ok("O2 exit", 0, code)
    ok("O2 args", ["--settings", "--add-dir=", "--effort", "high", "-p", "x"],
       [a.split("=")[0] + "=" if a.startswith("--add-dir=") else a for a in args if not a.startswith("/")])
    settings, memory = files(args)
    ok("O2 the team AGENTS.md import is excluded", [str(root / ".claude" / "CLAUDE.md")], settings["claudeMdExcludes"])
    ok("O2 the added directory's CLAUDE.md is loaded", "1", settings["env"]["CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD"])
    ok("O2 only skills outside the keep-set are hidden",
       {"pl-bench-tasks": "user-invocable-only", "pl-customer-service-transcripts": "user-invocable-only",
        "pl-demo-video-edit": "user-invocable-only"}, settings["skillOverrides"])
    ok("O2 the cut parts are gone", [False] * 6, [t in memory for t in (
        "Optional session transcript sharing", "Track substantive coding work", "## Scheduling corpus capture",
        "pl-internal-workspace", "hub/AGENTS.md", "delivery-team/")])
    ok("O2 the rest stays", [True] * 6, [t in memory for t in (
        "Merge a PR only when", "## Dependencies", "Intro line.", "- `packages/loopy/AGENTS.md` — purity.\n",
        "Scope and judge work", "## Shared workflows")])
    ok("O2 it names the checkout its paths are relative to", True, f"relative to {root}." in memory.splitlines()[0])
    ok("O2 the operator note ends it", True, memory.rstrip().endswith("With no such card, skip those steps."))
    ok("O2 one line says what it did", True, said.startswith("planlab overlay: ") and "3 of 10 repository skills hidden" in said)

if want("O3"):  # a given --settings is merged in, its keys winning, and leaves the args
    home, root, config = world("O3")
    given = home / "mine.json"
    given.write_text(json.dumps({"skillOverrides": {"pl-bench-tasks": "on"}, "claudeMdExcludes": ["/x/CLAUDE.md"],
                                 "env": {"MINE": "1"}}))
    code, args = run(home, config, root, "--settings", '{"fastMode":true}', f"--settings={given}", "-c")
    settings, _ = files(args)
    ok("O3 exit", 0, code)
    ok("O3 one --settings left", 1, args.count("--settings") + sum(a.startswith("--settings=") for a in args))
    ok("O3 fastMode carried", True, settings.get("fastMode"))
    ok("O3 the given override wins", "on", settings["skillOverrides"]["pl-bench-tasks"])
    ok("O3 exclusions add up", [str(root / ".claude" / "CLAUDE.md"), "/x/CLAUDE.md"], settings["claudeMdExcludes"])
    ok("O3 env merges", {"CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD": "1", "MINE": "1"}, settings["env"])
    ok("O3 other args stay", ["-c"], args[3:])

if want("O4"):  # a renamed section stays in, and the miss is named when the session starts
    home, root, config = world("O4", AGENTS.replace("## Optional session transcript sharing", "## Sharing transcripts"))
    code, args, said = run(home, config, root, err=True)
    _, memory = files(args)
    ok("O4 still overlays", 0, code)
    ok("O4 the renamed section stays", True, "## Sharing transcripts" in memory)
    ok("O4 the miss is named", True, "no match, left in: 'Optional session transcript sharing'" in said)

if want("O5"):  # a flag it cannot combine with, or a --settings it cannot read, keeps the args and says why
    home, root, config = world("O5")
    for flags in (["--setting-sources", "user"], ["--settings", "{not json"], ["--settings", str(home / "missing.json")],
                  ["--settings"]):
        code, args, said = run(home, config, root, *flags, err=True)
        ok(f"O5 {flags[0]} keeps the args and says so", (1, [], True), (code, args, "not applied" in said))
    code, args = run(home, config, root, "--append-system-prompt", "mine")
    ok("O5 an appended prompt of one's own passes through", (0, ["--append-system-prompt", "mine"]), (code, args[3:]))

if want("O6"):  # words after -- are the vendor's, untouched
    home, root, config = world("O6")
    code, args = run(home, config, root, "-p", "--", "--settings", "kept", "--setting-sources", "y")
    ok("O6 after --", ["-p", "--", "--settings", "kept", "--setting-sources", "y"], args[3:])

if want("O7"):  # an empty argument survives the NUL framing, and a prompt after the added directory stays a prompt
    home, root, config = world("O7")
    code, args = run(home, config, root, "--tools", "", "-p", "x")
    ok("O7 empty arg kept", ["--tools", "", "-p", "x"], args[3:])
    ok("O7 the directory is one = argument", True, args[2].startswith("--add-dir=/"))

if want("O8"):  # files are named for their content: same launch, same files; another fastMode, another settings file
    home, root, config = world("O8")
    first = run(home, config, root)[1]
    second = run(home, config, root)[1]
    fast = run(home, config, root, "--settings", '{"fastMode":true}')[1]
    ok("O8 same launch reuses its files", first[:2], second[:2])
    ok("O8 other settings get another file, the same memory", True, first[1] != fast[1] and first[2] == fast[2])
    ok("O8 cache lives under XDG_CACHE_HOME", True,
       first[1].startswith(str(home / ".cache" / "claude-planlab-overlay")) and str(home / ".cache") in first[2])

if want("O10"):  # a config it cannot use keeps the args and says why
    home, root, config = world("O10")
    broken = home / "broken.toml"
    for name, text in (("missing", None), ("not TOML", "keep = ["), ("no skills table", "[agents]\n"),
                       ("keep not a list", '[skills]\nkeep = "pl-*"\n[agents]\n')):
        if text is not None:
            broken.write_text(text)
        code, args, said = run(home, config, root, "-p", "x", err=True,
                               overlay_config=broken if text is not None else home / "none.toml")
        ok(f"O10 {name} keeps the args and says so", (1, [], True), (code, args, "not applied" in said))
    old = shutil.which("python3", path="/usr/bin")
    probe = subprocess.run([old, "-c", "import tomllib"], capture_output=True) if old else None
    if probe is not None and probe.returncode != 0:  # a python3 without tomllib, as macOS ships
        code, args, said = run(home, config, root, "-p", "x", python=old, err=True)
        ok("O10 a python3 without tomllib keeps the args and says so", (1, [], True), (code, args, "tomllib" in said))

if want("O11"):  # --show: the cuts as a diff, the note, the misses, the hooks' switches, and the visible skills
    home, root, config = world("O11", AGENTS.replace("## Scheduling corpus capture", "## Corpus samples"))
    code, out = run(home, config, root, "--show", raw=True)
    ok("O11 exit", 0, code)
    ok("O11 a cut shows as a removed line", True, "\n-## Optional session transcript sharing\n" in out)
    ok("O11 the note is shown", True, "## Bench, transcripts and corpus samples, for this user" in out)
    ok("O11 a miss is named", True, "no match, left in: Scheduling corpus capture" in out)
    ok("O11 a hook without the switch is named", True,
       "PLANLAB_BENCH_REMINDERS: this checkout has no lifecycle.py" in out)
    ok("O11 visible skills listed", True, "pl-backstage-db" in out.splitlines()[-1]
       and "pl-demo-video-edit" not in out.splitlines()[-1])
    ok("O11 outside a checkout it fails", 1, run(home, config, home, "--show", raw=True)[0])

if want("O9"):  # the real cache and log were never reached
    ok("O9 real cache and log untouched", REAL_BEFORE, (stamp(REAL_CACHE), stamp(REAL_LOG)))

if os.environ.get("KEEP"):
    print(f"kept {SANDBOX}")
elif SANDBOX.is_absolute() and SANDBOX.name.startswith("planlab-overlay-test."):
    shutil.rmtree(SANDBOX)

print(f"PASS {PASS}  FAIL {FAIL}" + (f"  ({' '.join(FAILED)})" if FAILED else ""))
sys.exit(1 if FAIL else 0)

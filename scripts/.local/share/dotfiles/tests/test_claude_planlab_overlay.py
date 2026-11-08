#!/usr/bin/env python3
"""test_claude_planlab_overlay.py — claude-planlab-overlay's contract: inside a
PlanLab checkout a launch's args come back with one merged --settings (the
team AGENTS.md excluded, skills outside the keep-set hidden, the operator's
own skill names untouched) and a filtered AGENTS.md as the appended system
prompt; anywhere else, or on anything it cannot read, it prints nothing and
exits 1 so the launch keeps its args.

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

## Shared workflows

Track substantive coding work in Bench as the skill describes: run
`bench tasks start <ref>` before the work.

Merge a PR only when the user approved merging that PR, and only through
`pl-land`.

## Optional session transcript sharing

Offer transcript sharing after substantive work of any kind.

## Dependencies

The package manager is pnpm.
"""

SKILLS = ["pl-loopy-onboarding", "pl-deploy-taodesk", "pl-pr", "pl-land", "pl-update-cli",
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


def run(home, config, cwd, *args):
    env = {"HOME": str(home), "XDG_CACHE_HOME": str(home / ".cache"), "CLAUDE_CONFIG_DIR": str(config),
           "PATH": os.environ.get("PATH", "/usr/bin:/bin"), "PWD": str(cwd)}
    done = subprocess.run([sys.executable, "-I", str(SCRIPT), *args], cwd=cwd, env=env, capture_output=True)
    out = done.stdout.decode()
    return done.returncode, (out.split("\0")[:-1] if out else [])


def files(args):
    settings = json.loads(Path(args[args.index("--settings") + 1]).read_text())
    prompt = Path(args[args.index("--append-system-prompt-file") + 1]).read_text()
    return settings, prompt


if want("O1"):  # outside a checkout the launch keeps its args
    home, root, config = world("O1")
    ok("O1 home is not a checkout", (1, []), run(home, config, home, "-p", "x"))
    other = home / "dev" / "other"
    (other / ".claude").mkdir(parents=True)
    (other / ".claude" / "CLAUDE.md").write_text("# another project\n")
    ok("O1 another repository is not one", (1, []), run(home, config, other, "-p", "x"))

if want("O2"):  # inside one: the two files lead, the launch's args follow
    home, root, config = world("O2")
    code, args = run(home, config, root / "application", "--effort", "high", "-p", "x")
    ok("O2 exit", 0, code)
    ok("O2 args", ["--settings", "--append-system-prompt-file", "--effort", "high", "-p", "x"],
       [a for a in args if not a.startswith("/")])
    settings, prompt = files(args)
    ok("O2 the team AGENTS.md import is excluded", [str(root / ".claude" / "CLAUDE.md")], settings["claudeMdExcludes"])
    ok("O2 only skills outside the keep-set are hidden",
       {"pl-bench-tasks": "user-invocable-only", "pl-customer-service-transcripts": "user-invocable-only",
        "pl-demo-video-edit": "user-invocable-only"}, settings["skillOverrides"])
    ok("O2 transcript section gone", False, "Optional session transcript sharing" in prompt)
    ok("O2 tracking paragraph gone", False, "Track substantive coding work" in prompt)
    ok("O2 the rest stays", [True, True, True], ["Merge a PR only when" in prompt, "## Dependencies" in prompt,
                                                 "Intro line." in prompt])
    ok("O2 the operator note ends it", True, prompt.rstrip().endswith("that the PR skills run."))

if want("O3"):  # a given --settings is merged in, its keys winning, and leaves the args
    home, root, config = world("O3")
    given = home / "mine.json"
    given.write_text(json.dumps({"skillOverrides": {"pl-bench-tasks": "on"}, "claudeMdExcludes": ["/x/CLAUDE.md"]}))
    code, args = run(home, config, root, "--settings", '{"fastMode":true}', f"--settings={given}", "-c")
    settings, _ = files(args)
    ok("O3 exit", 0, code)
    ok("O3 one --settings left", 1, args.count("--settings") + sum(a.startswith("--settings=") for a in args))
    ok("O3 fastMode carried", True, settings.get("fastMode"))
    ok("O3 the given override wins", "on", settings["skillOverrides"]["pl-bench-tasks"])
    ok("O3 exclusions add up", [str(root / ".claude" / "CLAUDE.md"), "/x/CLAUDE.md"], settings["claudeMdExcludes"])
    ok("O3 other args stay", ["-c"], args[4:])

if want("O4"):  # a renamed section stays in, and the miss is logged
    home, root, config = world("O4", AGENTS.replace("## Optional session transcript sharing", "## Sharing transcripts"))
    code, args = run(home, config, root)
    _, prompt = files(args)
    ok("O4 still overlays", 0, code)
    ok("O4 the renamed section stays", True, "## Sharing transcripts" in prompt)
    log = home / ".local" / "state" / "claude-planlab-overlay.log"
    ok("O4 the miss is logged", True, log.is_file() and "Optional session transcript sharing" in log.read_text())

if want("O5"):  # flags it cannot combine with, or a --settings it cannot read, keep the args
    home, root, config = world("O5")
    for flags in (["--append-system-prompt", "x"], ["--system-prompt-file=f"], ["--setting-sources", "user"],
                  ["--settings", "{not json"], ["--settings", str(home / "missing.json")], ["--settings"]):
        ok(f"O5 {flags[0]} keeps the args", (1, []), run(home, config, root, *flags))

if want("O6"):  # words after -- are the vendor's, untouched
    home, root, config = world("O6")
    code, args = run(home, config, root, "-p", "--", "--settings", "kept", "--append-system-prompt", "y")
    ok("O6 after --", ["-p", "--", "--settings", "kept", "--append-system-prompt", "y"], args[4:])

if want("O7"):  # an empty argument survives the NUL framing
    home, root, config = world("O7")
    code, args = run(home, config, root, "--tools", "", "-p", "x")
    ok("O7 empty arg kept", ["--tools", "", "-p", "x"], args[4:])

if want("O8"):  # files are named for their content: same launch, same files; another fastMode, another file
    home, root, config = world("O8")
    first = run(home, config, root)[1]
    second = run(home, config, root)[1]
    fast = run(home, config, root, "--settings", '{"fastMode":true}')[1]
    ok("O8 same launch reuses its files", first[:4], second[:4])
    ok("O8 other settings get another file", True, first[1] != fast[1] and first[3] == fast[3])
    ok("O8 cache lives under XDG_CACHE_HOME", True, first[1].startswith(str(home / ".cache" / "claude-planlab-overlay")))

if want("O9"):  # the real cache and log were never reached
    ok("O9 real cache and log untouched", REAL_BEFORE, (stamp(REAL_CACHE), stamp(REAL_LOG)))

if os.environ.get("KEEP"):
    print(f"kept {SANDBOX}")
elif SANDBOX.is_absolute() and SANDBOX.name.startswith("planlab-overlay-test."):
    shutil.rmtree(SANDBOX)

print(f"PASS {PASS}  FAIL {FAIL}" + (f"  ({' '.join(FAILED)})" if FAILED else ""))
sys.exit(1 if FAIL else 0)

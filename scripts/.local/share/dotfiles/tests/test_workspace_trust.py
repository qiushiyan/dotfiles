#!/usr/bin/env python3
"""test_workspace_trust.py — workspace-trust's contract: the roots and every
repository under them are trusted in each Claude Code account and in Codex, a
settled state is never rewritten, --prune removes only what its rule names,
and a file it cannot handle is left byte for byte.

Usage: python3 test_workspace_trust.py [W1 W4 ...]

ISOLATION. HOME is the script's only input, and every case gives it a fresh
temporary one, so the real accounts are never read. The suite runs from a
scratch directory. W9 asserts the real Codex config is unchanged and that no
real Claude Code file names a sandbox path.
"""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib

SCRIPT = Path(__file__).resolve().parents[3] / "bin" / "workspace-trust"
REAL_HOME = Path.home()
REAL_CODEX = REAL_HOME / ".codex" / "config.toml"
ONLY = sys.argv[1:]
PASS = FAIL = 0
FAILED = []

SANDBOX = Path(tempfile.mkdtemp(prefix="workspace-trust-test.")).resolve()
os.chdir(SANDBOX)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


REAL_CODEX_BEFORE = digest(REAL_CODEX)

CODEX_CONFIG = '''model = "gpt-test"

[mcp_servers.context7]
  command = "npx"
  args = ["-y", "ctx7"]

[projects]
  [projects."{home}"]
    trust_level = "trusted"
  [projects."{home}/dev/alpha"]
    trust_level = "untrusted"
  [projects."/private/tmp"]
    trust_level = "trusted"
  [projects."{home}/old-machine/gone"]
    trust_level = "trusted"

[shell_environment_policy]
  inherit = "all"

[projects."{home}/dev/by-hand"]
trust_level = "trusted"
'''


def ok(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        PASS += 1
    else:
        FAIL += 1
        FAILED.append(name)
        print(f"  FAIL {name}\n    expected: {expected!r}\n    actual:   {actual!r}")


def repo(path):
    (path / ".git").mkdir(parents=True)


def home(case):
    """A home with three roots, repositories at several depths, a linked
    worktree, a primary and one extra account for each vendor."""
    h = SANDBOX / case
    repo(h / "dev" / "alpha")
    repo(h / "dev" / "group" / "main")
    repo(h / "dev" / "alpha" / "apps" / "nested")
    repo(h / "dev" / "a" / "b" / "c" / "d" / "too-deep")
    repo(h / "dev" / "alpha" / "node_modules" / "vendored")
    repo(h / "dotfiles")
    repo(h / "wiki")
    (h / "dev" / "by-hand").mkdir()
    (h / "dev" / ".worktrees" / "alpha" / "feat").mkdir(parents=True)
    (h / "dev" / ".worktrees" / "alpha" / "feat" / ".git").write_text(
        f"gitdir: {h}/dev/alpha/.git/worktrees/feat\n")
    (h / "elsewhere").mkdir()

    state = {
        "numStartups": 7,
        "oauthAccount": {"emailAddress": "a@example.com"},
        "projects": {
            str(h): {"hasTrustDialogAccepted": False},
            str(h / "dev" / "alpha"): {"hasTrustDialogAccepted": False, "lastCost": 1.25},
            str(h / "elsewhere"): {"hasTrustDialogAccepted": True, "mcpServers": {"x": {}}},
            str(h / "dev" / "deleted"): {"hasTrustDialogAccepted": True},
            "/Volumes/unplugged/project": {"hasTrustDialogAccepted": True},
        },
    }
    (h / ".claude-accounts" / "b@example.com").mkdir(parents=True)
    (h / ".claude-accounts" / "c@example.com.lock").mkdir()
    (h / ".claude-accounts" / "empty@example.com").mkdir()
    for f in (h / ".claude.json", h / ".claude-accounts" / "b@example.com" / ".claude.json"):
        f.write_text(json.dumps(state, indent=2))
        f.chmod(0o600)

    (h / ".codex").mkdir()
    (h / ".codex" / "config.toml").write_text(CODEX_CONFIG.format(home=h))
    (h / ".codex" / "config.toml").chmod(0o600)
    (h / ".codex-accounts" / "b@example.com").mkdir(parents=True)
    (h / ".codex-accounts" / "b@example.com" / "config.toml").symlink_to(h / ".codex" / "config.toml")
    return h


def run(h, *args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True,
        env={"HOME": str(h), "PATH": "/usr/bin:/bin"}, cwd=SANDBOX,
    )


def claude(h, account=None):
    f = h / ".claude-accounts" / account / ".claude.json" if account else h / ".claude.json"
    return json.loads(f.read_text())


def trusted(projects):
    return sorted(p for p, e in projects.items() if e.get("hasTrustDialogAccepted") is True)


def codex(h):
    return tomllib.loads((h / ".codex" / "config.toml").read_text())


def codex_projects(h):
    return codex(h).get("projects", {})


def expected_dirs(h):
    return sorted(str(h / p) for p in (
        "dev", "dev/alpha", "dev/alpha/apps/nested", "dev/group/main", "dotfiles", "wiki"))


def stamps(h):
    files = [h / ".claude.json", h / ".claude-accounts" / "b@example.com" / ".claude.json",
             h / ".codex" / "config.toml"]
    return [(f.stat().st_ino, f.stat().st_mtime_ns) for f in files]


def want(case):
    return not ONLY or case in ONLY


if want("W1"):  # a plain run trusts the roots and their repositories everywhere
    h = home("W1")
    r = run(h)
    ok("W1 exit", 0, r.returncode)
    want_dirs = expected_dirs(h)
    hand = [str(h / "dev" / "deleted"), str(h / "elsewhere"), "/Volumes/unplugged/project"]
    for account in (None, "b@example.com"):
        data = claude(h, account)
        ok(f"W1 claude trusted {account}", sorted(want_dirs + hand), trusted(data["projects"]))
        ok(f"W1 claude other state {account}",
           (7, "a@example.com", 1.25),
           (data["numStartups"], data["oauthAccount"]["emailAddress"],
            data["projects"][str(h / "dev" / "alpha")]["lastCost"]))
    projects = codex_projects(h)
    ok("W1 codex trusted",
       sorted(want_dirs + [str(h), str(h / "dev" / "by-hand"), str(h / "old-machine" / "gone"),
                           "/private/tmp"]),
       sorted(p for p, e in projects.items() if e == {"trust_level": "trusted"}))
    ok("W1 codex rest", ("gpt-test", ["-y", "ctx7"], "all"),
       (codex(h)["model"], codex(h)["mcp_servers"]["context7"]["args"],
        codex(h)["shell_environment_policy"]["inherit"]))

if want("W2"):  # a settled state is not rewritten
    h = home("W2")
    run(h)
    before = stamps(h)
    r = run(h)
    ok("W2 exit", 0, r.returncode)
    ok("W2 files not rewritten", before, stamps(h))
    ok("W2 says so", True, "nothing to change (6 directories trusted)" in r.stdout)
    ok("W2 quiet is silent", ("", ""), (run(h, "-q").stdout, run(h, "-q").stderr))

if want("W3"):  # --prune removes the gone and takes back trust outside the roots
    h = home("W3")
    r = run(h, "--prune")
    ok("W3 exit", 0, r.returncode)
    data = claude(h, "b@example.com")
    ok("W3 claude trusted", sorted(expected_dirs(h) + ["/Volumes/unplugged/project"]),
       trusted(data["projects"]))
    ok("W3 claude gone entry deleted", False, str(h / "dev" / "deleted") in data["projects"])
    ok("W3 claude outside keeps its state",
       {"hasTrustDialogAccepted": False, "mcpServers": {"x": {}}},
       data["projects"][str(h / "elsewhere")])
    ok("W3 codex is the rule and what lies under it",
       sorted(expected_dirs(h) + [str(h / "dev" / "by-hand")]), sorted(codex_projects(h)))
    ok("W3 names each removal", True,
       "removed  ~/dev/deleted" in r.stdout and "revoked  ~/elsewhere" in r.stdout
       and "removed  /private/tmp" in r.stdout)

if want("W4"):  # a dry run reports and writes nothing
    h = home("W4")
    before = stamps(h)
    r = run(h, "--prune", "-n")
    ok("W4 exit", 0, r.returncode)
    ok("W4 files untouched", before, stamps(h))
    ok("W4 reports", True,
       "trusted  ~/dev/group/main" in r.stdout and "dry run: nothing was written" in r.stdout)

if want("W5"):  # a file Claude Code holds locked is skipped; the rest is written
    h = home("W5")
    lock = h / ".claude.json.lock"
    lock.mkdir()
    before = digest(h / ".claude.json")
    r = run(h)
    ok("W5 exit", 1, r.returncode)
    ok("W5 locked file untouched", before, digest(h / ".claude.json"))
    ok("W5 says which", True, "~/.claude.json is locked" in r.stderr)
    ok("W5 the lock is still its owner's", True, lock.is_dir())
    ok("W5 other account written", expected_dirs(h),
       [p for p in trusted(claude(h, "b@example.com")["projects"]) if p in expected_dirs(h)])

if want("W6"):  # Codex: only the projects tables move; link, mode and the rest stay
    h = home("W6")
    run(h, "--prune")
    text = (h / ".codex" / "config.toml").read_text()
    head, _, tail = text.partition("[projects]\n")
    ok("W6 text before the block", CODEX_CONFIG.format(home=h).partition("[projects]\n")[0], head)
    ok("W6 text after the block", '\n[shell_environment_policy]\n  inherit = "all"\n',
       tail[tail.index("\n[shell_environment_policy]"):].rstrip("\n") + "\n")
    ok("W6 one projects block", 1, text.count("[projects]"))
    ok("W6 extra home still links", True,
       (h / ".codex-accounts" / "b@example.com" / "config.toml").is_symlink())
    ok("W6 modes kept", (0o600, 0o600),
       ((h / ".codex" / "config.toml").stat().st_mode & 0o777, (h / ".claude.json").stat().st_mode & 0o777))
    bare = home("W6b")
    (bare / ".codex" / "config.toml").write_text('model = "gpt-test"')
    run(bare)
    ok("W6 a config with no projects gains them",
       ("gpt-test", expected_dirs(bare)),
       (codex(bare)["model"], sorted(codex_projects(bare))))

if want("W7"):  # what cannot be rewritten safely is refused whole
    h = home("W7")
    inline = 'model = "m"\nprojects = { "/x" = { trust_level = "trusted" } }\n'
    (h / ".codex" / "config.toml").write_text(inline)
    (h / ".claude.json").write_text("{ not json")
    r = run(h)
    ok("W7 exit", 1, r.returncode)
    ok("W7 codex untouched", inline, (h / ".codex" / "config.toml").read_text())
    ok("W7 claude untouched", "{ not json", (h / ".claude.json").read_text())
    ok("W7 names both", True, "config.toml would not parse after the edit" in r.stderr
       and "~/.claude.json cannot be read as JSON" in r.stderr)
    ok("W7 the readable account is still written", expected_dirs(h),
       [p for p in trusted(claude(h, "b@example.com")["projects"]) if p in expected_dirs(h)])

if want("W8"):  # nothing is created: no account file, no debris
    h = home("W8")
    run(h, "--prune")
    ok("W8 lock debris is not an account", [],
       sorted(p.name for p in (h / ".claude-accounts" / "c@example.com.lock").iterdir()))
    ok("W8 an account with no state gets none", [],
       sorted(p.name for p in (h / ".claude-accounts" / "empty@example.com").iterdir()))
    ok("W8 no temp files or locks left",
       [".claude-accounts", ".claude.json", ".codex", ".codex-accounts"],
       sorted(p.name for p in h.iterdir() if p.name.startswith(".")))
    ok("W8 account dir holds its file alone", [".claude.json"],
       sorted(p.name for p in (h / ".claude-accounts" / "b@example.com").iterdir()))
    ok("W8 codex home holds its file alone", ["config.toml"],
       sorted(p.name for p in (h / ".codex").iterdir()))

if want("W9"):  # the real homes were never reached
    ok("W9 real codex config unchanged", REAL_CODEX_BEFORE, digest(REAL_CODEX))
    real = [REAL_HOME / ".claude.json", *REAL_HOME.glob(".claude-accounts/*/.claude.json")]
    ok("W9 no real claude file names the sandbox", [],
       [str(f) for f in real if f.is_file() and str(SANDBOX) in f.read_text(errors="replace")])

if os.environ.get("KEEP"):
    print(f"kept {SANDBOX}")
elif SANDBOX.is_absolute() and SANDBOX.name.startswith("workspace-trust-test."):
    shutil.rmtree(SANDBOX)

print(f"PASS {PASS}  FAIL {FAIL}" + (f"  ({' '.join(FAILED)})" if FAILED else ""))
sys.exit(1 if FAIL else 0)

#!/usr/bin/env python3
"""PostToolUse(Bash) and Stop hook: a session that merged a PR closes it out
before it hands the turn back, so the user never has to ask for the closeout.

After a Bash command run from a checkout of a project listed in PROJECTS, the
hook reads the command with block-dangerous-git.py's lexer. A merge it starts
(`land-wait.sh <N> … --merge`, or `gh pr merge [<N>|<url>]`) is recorded as
owed for this session; the project's closeout check run for a PR
(`<check> <N>`) records that PR's closeout as begun. The record is a JSON file
named by the session id under
${XDG_STATE_HOME:-~/.local/state}/claude-hooks/closeout-owed/. A merge
usually runs in the background, so the command's output says nothing yet;
the record stands until the turn ends.

When the turn ends (Stop), each owed PR with no closeout begun and no
reminder yet is asked of GitHub (`gh pr view`, LIMIT seconds). One that reads
MERGED gets one reminder, as additionalContext, which keeps the session going
with it: closing out is the session's next step, unless the turn stopped on
something the user must answer. A PR still open stays owed for a later turn
end; one closed unmerged is dropped. A `gh pr merge` with no number names the
PR of the branch checked out where it ran, asked at that point.

It speaks once per PR per session, and stays silent on whatever it cannot
establish: a payload without a session id or a cwd, a cwd outside every
project, no gh, a slow or unreadable answer, a record it cannot write. It
never returns a block decision. The message names the skill and the path
of its file, so a session the overlay did not launch can still read it.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import time

# One entry per project: where its checkouts live, the skill that closes out
# a merged PR, that skill's file, and the closeout check whose run for a PR
# marks its closeout begun (matched by the script's file name).
PROJECTS = (
    {
        "name": "Planlab",
        "checkouts": ("~/dev/planlab/main", "~/dev/.worktrees/main"),
        "skill": "pl-closeout",
        "path": "~/.local/share/dotfiles/planlab-skills/pl-closeout/SKILL.md",
        "check": "closeout_check.py",
    },
)

LIMIT = 8   # seconds gh has to answer, per PR
SESSION_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
PR_URL = re.compile(r"/pull/(\d+)")
HERE = os.path.dirname(os.path.realpath(__file__))

MESSAGE = (
    "{prs} merged in this session. Unless this turn stopped on something the "
    "user must answer, closing {them} out is your next step, not the user's: "
    "load {skill} now (where it is not installed, read {path}). It ships the "
    "change, takes what the merge owes and cleans up what the branch started."
)


def project_of(cwd):
    here = os.path.realpath(cwd)
    for project in PROJECTS:
        for checkout in project["checkouts"]:
            root = os.path.realpath(os.path.expanduser(checkout))
            if here == root or here.startswith(root + os.sep):
                return project
    return None


def shell():
    spec = importlib.util.spec_from_file_location("shell_reading", os.path.join(HERE, "block-dangerous-git.py"))
    sh = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sh)
    return sh


def number(word):
    """The PR a merge's operand names: a number, or a URL ending in /pull/<N>."""
    if word.isdigit():
        return word
    found = PR_URL.search(word)
    return found.group(1) if found else None


def seen(command, project):
    """(PRs a merge was started for, PRs whose closeout check ran) in a command; "" stands for the branch's own PR."""
    sh = shell()
    merges, checks = [], []
    for argv in sh.commands(command):
        _, argv = sh.strip_prefix(argv)
        if not argv:
            continue
        name = os.path.basename(argv[0])
        args = argv[1:]
        if name in ("python3", "python") and args:
            name, args = os.path.basename(args[0]), args[1:]
        operands = [a for a in args if not a.startswith("-")]
        if name == "land-wait.sh" and "--merge" in args and operands and operands[0].isdigit():
            merges.append(operands[0])
        elif name == "gh" and "--help" not in args:
            rest = [a for a in args if not a.startswith("-")]
            if rest[:2] == ["pr", "merge"]:
                merges.append(next((n for n in map(number, rest[2:3]) if n), ""))
        elif name == project["check"] and operands and operands[0].isdigit():
            checks.append(operands[0])
    return merges, checks


def record_path(session_id):
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(state, "claude-hooks", "closeout-owed", session_id + ".json")


def load(path):
    try:
        with open(path) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def gh_view(args, cwd):
    """gh pr view's JSON answer, or None."""
    try:
        done = subprocess.run(["gh", "pr", "view", *args, "--json", "number,state"], cwd=cwd,
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              timeout=LIMIT, check=True)
        answer = json.loads(done.stdout)
        return answer if isinstance(answer, dict) else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def after_bash(payload):
    command, cwd, session_id = payload["tool_input"]["command"], payload["cwd"], payload["session_id"]
    if not (isinstance(command, str) and isinstance(cwd, str) and isinstance(session_id, str)):
        return
    if not os.path.isabs(cwd) or not SESSION_ID.fullmatch(session_id):
        return
    project = project_of(cwd)
    if project is None:
        return
    merges, checks = seen(command, project)
    if not merges and not checks:
        return
    path = record_path(session_id)
    data = load(path)
    owed, begun = data.setdefault("owed", {}), data.setdefault("begun", [])
    for pr in merges:
        if not pr:
            answer = gh_view([], cwd)
            pr = str(answer["number"]) if answer and answer.get("number") else ""
        if pr and pr not in owed:
            owed[pr] = {"cwd": cwd, "at": int(time.time())}
    for pr in checks:
        if pr not in begun:
            begun.append(pr)
    save(path, data)


def at_stop(payload):
    """The reminder to give, or None."""
    cwd, session_id = payload["cwd"], payload["session_id"]
    if not (isinstance(cwd, str) and isinstance(session_id, str)) or not SESSION_ID.fullmatch(session_id):
        return None
    project = project_of(cwd)
    if project is None:
        return None
    path = record_path(session_id)
    if not os.path.exists(path):
        return None
    data = load(path)
    owed, begun, reminded = data.get("owed", {}), data.get("begun", []), data.setdefault("reminded", [])
    merged = []
    for pr, where in list(owed.items()):
        if pr in begun or pr in reminded:
            continue
        answer = gh_view([pr], where.get("cwd") or cwd)
        if not answer:
            continue
        if answer.get("state") == "MERGED":
            merged.append(pr)
        elif answer.get("state") == "CLOSED":
            del owed[pr]
    if not merged:
        save(path, data)
        return None
    reminded.extend(merged)
    save(path, data)
    prs = " and ".join(f"#{n}" for n in merged)
    return MESSAGE.format(prs=prs, them="them" if len(merged) > 1 else "it",
                          skill=project["skill"], path=project["path"])


def main():
    try:
        payload = json.load(sys.stdin)
        event = payload.get("hook_event_name")
        if event == "PostToolUse" and payload.get("tool_name") == "Bash":
            after_bash(payload)
        elif event == "Stop":
            message = at_stop(payload)
            if message:
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": message}}))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())

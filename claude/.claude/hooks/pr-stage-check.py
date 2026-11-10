#!/usr/bin/env python3
"""PreToolUse(Bash) hook: stop the first `gh pr create` of a session that has
run no review round, once, and say what to run first.

In a project listed in PROJECTS a pull request follows a review round. When a
Bash command run from one of the project's checkouts opens a pull request,
the hook asks claude-steps what the session has run
(`claude-steps show <session id> --json`). If the session was read whole
(`status` is ok) and its `review` label has no step, the call is refused with
a message that names the project's review snippet, and its prompt check too
when the `prompts` label has no step either.

Advisory. It speaks once per session: a marker file named by the session id,
under ${XDG_STATE_HOME:-~/.local/state}/claude-hooks/pr-stage-check/, lets
every later `gh pr create` of that session through, so the second attempt
passes. Whatever it cannot establish passes in silence: a payload without a
session id or a cwd, no claude-steps on PATH, an answer slower than LIMIT
seconds or one that is not the JSON `claude-steps show --help` documents, a
view that is partial, unreadable or missing, labels without a `review`, and a
marker that cannot be written, since a refusal it could not remember would
repeat.

The shell reading is block-dangerous-git.py's lexer, loaded from beside this
file, so `gh pr create` counts wherever the shell would run it (behind
`cd … &&`, VAR=value prefixes and wrappers, inside a command substitution)
and nowhere else: quoted text, quoted heredoc bodies and comments stay inert.
`gh pr new` is the same command; with `--help` or `--dry-run` it opens
nothing and passes. Out of scope, as there: gh aliases, `gh api`, and strings
handed to another interpreter. Only the payload's cwd places the command; a
`cd` inside it is not followed. Exit 2 refuses (stderr goes to the model).
"""
import importlib.util
import json
import os
import re
import subprocess
import sys

# One entry per project. The session is in the project when its cwd is one of
# `checkouts` or below it. `review` and `prompt_check` are the keys of TabType
# snippets in `file`, which the message prints as it is written here.
PROJECTS = (
    {
        "name": "PlanLab",
        "checkouts": ("~/dev/planlab/main", "~/dev/.worktrees/main"),
        "review": "loopy-review-verify",
        "prompt_check": "loopy-prompt-check",
        "file": "~/dev/planlab/main/.tabtype.local.toml",
    },
)

LIMIT = 5   # seconds claude-steps has to answer
SESSION_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")  # a file name, and never an option
HERE = os.path.dirname(os.path.realpath(__file__))

MESSAGE = (
    "No review round has run in this session, and this command opens a pull "
    "request. For a change that alters behaviour, the review and the "
    "verification come first: read the `{review}` entry in {file}, do what it "
    "says, fix what you confirm, then run this command again. For a docs-only "
    "change, a review that ran in another session, or a review the user told "
    "you to skip, run the command again as it is and say in your report which "
    "it was.\n"
)
PROMPT_CHECK = (
    "\nIf the change touches text a model reads (a prompt, a tool's "
    "description or result, a skill), the `{prompt_check}` entry in the same "
    "file comes before the pull request too.\n"
)


def project_of(cwd):
    """The PROJECTS entry whose checkouts hold `cwd`, else None."""
    here = os.path.realpath(cwd)
    for project in PROJECTS:
        for checkout in project["checkouts"]:
            root = os.path.realpath(os.path.expanduser(checkout))
            if here == root or here.startswith(root + os.sep):
                return project
    return None


def opens_pull_request(command):
    """Whether a simple command the shell would run is `gh pr create`."""
    spec = importlib.util.spec_from_file_location(
        "shell_reading", os.path.join(HERE, "block-dangerous-git.py"))
    sh = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sh)
    for argv in sh.commands(command):
        _, argv = sh.strip_prefix(argv)
        if not argv or os.path.basename(argv[0]) != "gh":
            continue
        args = argv[1:]
        if "--help" in args or "--dry-run" in args:
            continue
        # The first two operands; -R/--repo may stand before the subcommand.
        operands, i = [], 0
        while i < len(args) and len(operands) < 2:
            if args[i] in ("-R", "--repo"):
                i += 2
                continue
            if not args[i].startswith("-"):
                operands.append(args[i])
            i += 1
        if operands in (["pr", "create"], ["pr", "new"]):
            return True
    return False


def has_step(view, name):
    """True or False for a label of the view; None when it has no such label,
    which says nothing either way."""
    for label in view["labels"]:
        if label["name"] == name:
            return label.get("latest") is not None
    return None


def refusal(payload):
    """The message that refuses this call, or None to let it through."""
    command = payload["tool_input"]["command"]
    cwd, session_id = payload["cwd"], payload["session_id"]
    if not (isinstance(command, str) and isinstance(cwd, str) and isinstance(session_id, str)):
        return None
    if not os.path.isabs(cwd) or not SESSION_ID.fullmatch(session_id):
        return None
    project = project_of(cwd)
    if project is None or not opens_pull_request(command):
        return None
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    marker = os.path.join(state, "claude-hooks", "pr-stage-check", session_id)
    if os.path.exists(marker):
        return None
    view = json.loads(subprocess.run(
        ["claude-steps", "show", session_id, "--json"],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        timeout=LIMIT, check=True,
    ).stdout)
    if view["status"] != "ok" or has_step(view, "review") is not False:
        return None
    message = MESSAGE.format(**project)
    if has_step(view, "prompts") is False:
        message += PROMPT_CHECK.format(**project)
    # The marker is the last step that can fail, so the hook never remembers a
    # refusal it did not make. O_EXCL raises when the marker is already there.
    os.makedirs(os.path.dirname(marker), exist_ok=True)
    os.close(os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644))
    return message


def main():
    try:
        message = refusal(json.load(sys.stdin))
    except Exception:
        return 0
    if not message:
        return 0
    sys.stderr.write(message)
    return 2


if __name__ == "__main__":
    sys.exit(main())

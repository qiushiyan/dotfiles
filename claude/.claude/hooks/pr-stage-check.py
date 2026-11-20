#!/usr/bin/env python3
"""PreToolUse(Bash) hook: stop the first `gh pr create` of a session that has
run no review round or no verification, once, and say when each one pays.

In a project listed in PROJECTS a pull request follows a review round and a
verification where the change needs them, and the session decides which it
does. When a Bash command run from one of the project's checkouts opens a
pull request, the hook asks claude-steps what the session has run
(`claude-steps show <session id> --json`). If the session was read whole
(`status` is ok) and its `review` or `verify` label has no step, the call is
refused with a message that says, for each one missing, what it catches and
when the change needs it, and names the prompt check too when the `prompts`
label has no step either. A label the view lacks says nothing either way.

Advisory. It speaks once per session: a marker file named by the session id,
under ${XDG_STATE_HOME:-~/.local/state}/claude-hooks/pr-stage-check/, lets
every later `gh pr create` of that session through, so the second attempt
passes. The marker holds JSON naming what was missing, so a later pass can
count the refusals by kind. Whatever it cannot establish passes in silence: a
payload without a session id or a cwd, no claude-steps on PATH, an answer
slower than LIMIT seconds or one that is not the JSON `claude-steps show
--help` documents, a view that is partial, unreadable or missing, labels
without a `review` or a `verify`, and a marker that cannot be written, since a
refusal it could not remember would repeat.

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
# snippets in `file`, which the message prints as it is written here; `verify`
# is the skill that verifies a branch.
PROJECTS = (
    {
        "name": "Planlab",
        "checkouts": ("~/dev/planlab/main", "~/dev/.worktrees/main"),
        "review": "review-verify",
        "prompt_check": "loopy-prompt-check",
        "verify": "pl-verify",
        "file": "~/dev/planlab/main/.tabtype.toml",
    },
)

LIMIT = 5   # seconds claude-steps has to answer
SESSION_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")  # a file name, and never an option
HERE = os.path.dirname(os.path.realpath(__file__))

# What the opening says has not run, by what is missing. The hook knows only
# what claude-steps saw load, so it names the skill, not the work.
NOT_RUN = {
    ("review", "verify"): "neither a review round with the review skill nor a verification with {verify}",
    ("review",): "no review round with the review skill",
    ("verify",): "no verification with {verify}",
}
OPENING = (
    "This command opens a pull request, and this session has run {not_run}. "
    "Decide what this change needs before the pull request opens, and say in "
    "your report what you ran and why you skipped the rest.\n"
)
# Each one's text says what it catches that the other does not, and when a
# change needs it (the evidence is in drive-session/EVIDENCE.md, 2026-11-16).
WHEN = {
    "review": (
        "\nA review (the review skill, as `astra full review`) catches what a "
        "careful reader of the code can: a defect in logic that spans modules, "
        "behaviour no test pins, and text that no longer matches the code, such "
        "as a skill or tool description a model reads, a doc, or a claim in the "
        "pull request. It pays for logic across several modules or a few "
        "hundred lines, a pattern later code will copy, text a model reads, or "
        "claims about production. A contained fix whose test fails without it "
        "rarely needs one.\n"
    ),
    "verify": (
        "\nA verification (the {verify} skill, which drives the change where "
        "it runs) shows what "
        "tests cannot reach: how a real model behaves with the new prompt or "
        "tool, real data's shape and size, the wiring between the app, the "
        "master and its workers, a restart or deploy in the middle of a run, "
        "timing on a real clock. Use the cheapest check that answers the "
        "question: a run with a real model in process often needs no lane, and "
        "a read of production gives real data's shape and size. When the tests "
        "already exercise what the change promises, as for a pure function, an "
        "engine change with its comparison tests, or a refactor that keeps "
        "behaviour, skip it.\n"
    ),
}
BOTH = "\nWhen both pay, the `{review}` entry in {file} starts them together.\n"
CLOSING = (
    "\nRun what this change needs, fix what it confirms, then run this command "
    "again. When none of it applies, as for a docs change that makes no new "
    "claim about the code or a model's behaviour, a step that ran in another "
    "session, a check you already ran here that answers it, or one the user "
    "told you to skip, run the command again as it is.\n"
)
PROMPT_CHECK = (
    "\nIf the change touches text a model reads (a prompt, a tool's "
    "description or result, a skill), the `{prompt_check}` entry in {file} "
    "comes before the pull request too.\n"
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
    which says nothing either way. A latest step that is only a prompt naming
    the label's skill (kind `mention`) ran nothing, so it counts as none. The
    view holds a label's latest step alone, so a run followed by a later
    mention also reads as none: one extra advisory stop, which the session
    answers with the run it made."""
    for label in view["labels"]:
        if label["name"] == name:
            latest = label.get("latest")
            return latest is not None and latest.get("kind") != "mention"
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
    if view["status"] != "ok":
        return None
    missing = tuple(name for name in ("review", "verify") if has_step(view, name) is False)
    if not missing:
        return None
    prompts = has_step(view, "prompts")
    message = OPENING.format(not_run=NOT_RUN[missing].format(**project))
    message += "".join(WHEN[name].format(**project) for name in missing)
    if len(missing) == 2:
        message += BOTH.format(**project)
    if prompts is False:
        message += PROMPT_CHECK.format(**project)
    message += CLOSING
    # The marker is the last step that can fail, so the hook never remembers a
    # refusal it did not make. O_EXCL raises when the marker is already there.
    record = json.dumps({"missing": list(missing), "prompt_check": prompts is not False})
    os.makedirs(os.path.dirname(marker), exist_ok=True)
    fd = os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    try:
        os.write(fd, record.encode() + b"\n")
    finally:
        os.close(fd)
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

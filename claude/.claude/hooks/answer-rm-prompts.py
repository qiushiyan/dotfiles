#!/usr/bin/env python3
"""PermissionRequest(Bash) hook: approve Claude Code's dangerous-rm prompt
when this hook can show the command's removals are safe, so an unattended
session keeps going instead of losing the command to the prompt's timeout.

Claude Code asks before a Bash command whose rm target it cannot resolve
(`rm -rf $S/x`), and before one it cannot parse well enough to rule out an
rm, such as a python heredoc that rewrites a file. No allow rule or
PreToolUse hook passes that prompt; a PermissionRequest hook's allow does
(code.claude.com/docs/en/permission-modes, § Critical-path removals in each
permission mode). The hook is not told why a prompt fired, so it answers
only prompts whose `permission_suggestions` is present and empty: a safety
check offers no "don't ask again", while an ordinary prompt always does.

It approves when every removal the shell would run (rm, rmdir, unlink,
including inside $(...), sh -c and trap) targets a path strictly inside a
temp directory (/tmp or $TMPDIR, but nothing above a session's own folder in
Claude Code's /tmp/claude-<uid>). A target may be literal, `~`, a variable
this same command set to a value the hook can resolve (`$S`, `${S}`,
`${S:?}`), and globs or braces below such a path. A command with no removal
is approved, since Claude Code would have run it had its parser read it. The
prompt is left for a person, or the drive bot, whenever a target is a
substitution, a variable set elsewhere or in a loop, a relative path with
no absolute cd before it in the command, or anything outside the temp directories, and whenever
xargs, parallel or find feed rm, find deletes, or eval runs a string.

The shell reading is block-dangerous-git.py's lexer, loaded from beside this
file; a failure to load it or to parse leaves the prompt alone. Each answer
is logged as a JSON line to $CLAUDE_RM_PROMPTS_LOG (unset: the state file
below; empty: no log).
"""
import importlib.util
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
_spec = importlib.util.spec_from_file_location("shell_reading", os.path.join(HERE, "block-dangerous-git.py"))
sh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sh)

REMOVERS = {"rm", "rmdir", "unlink"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
DECLARERS = {"export", "local", "typeset", "declare", "readonly"}
REBINDERS = {"for", "select", "read", "getopts", "unset", "mapfile", "readarray"}
APPEND = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\+=")
GLOB = re.compile(r"[*?\[{]")
VARIABLE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(:\?[^}]*)?\}|\$([A-Za-z_][A-Za-z0-9_]*)")
FROM_ENV = ("HOME", "TMPDIR")
DEFAULT_LOG = os.path.expanduser("~/.local/state/claude/rm-prompts.jsonl")


class Defer(Exception):
    """The command cannot be shown safe; the prompt stays."""


def temp_roots():
    roots = {os.path.realpath("/tmp")}
    if os.environ.get("TMPDIR"):
        roots.add(os.path.realpath(os.environ["TMPDIR"]))
    return roots


def safe_target(path):
    """Whether removing `path` (absolute, normalized, maybe globbed) stays
    strictly inside a temp directory."""
    parts = path.split("/")
    fixed = next((i for i, p in enumerate(parts) if GLOB.search(p)), len(parts))
    real = os.path.realpath("/".join(parts[:fixed]) or "/")
    if fixed == len(parts) and not path.endswith("/") and os.path.islink(path):
        # rm takes the link itself, not what it points at.
        real = os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path))
    claude = os.path.realpath("/tmp/claude-%d" % os.getuid())
    if real == claude or real.startswith(claude + "/"):
        # Each project's folder holds every session's scratchpad: only a
        # session's own folder and what is under it may go.
        return real.count("/") - claude.count("/") >= 2
    return any(real.startswith(r + "/") for r in temp_roots())


class Reading:
    """One pass over a command the way the shell runs it, in order."""

    def __init__(self, cwd, variables=None, depth=0):
        self.cwd = cwd
        self.vars = dict(variables or {})
        self.depth = depth
        self.traps = []

    def expand(self, word):
        """The word with ~ and known variables expanded, or None."""
        if "`" in word or "$(" in word:
            return None
        if word == "~" or word.startswith("~/"):
            word = "${HOME}" + word[1:]
        elif word.startswith("~"):
            return None
        unknown = []

        def value(m):
            name = m.group(1) or m.group(3)
            v = self.vars[name] if name in self.vars else (
                os.environ.get(name) if name in FROM_ENV else None)
            if not v:
                unknown.append(name)
                return ""
            return v
        out = VARIABLE.sub(value, word)
        return None if unknown or "$" in out else out

    def assign(self, word):
        name, _, raw = word.partition("=")
        self.vars[name] = self.expand(raw)

    def run(self, src):
        """Read `src` command by command. A ( or ` opens a subshell, whose cd
        and assignments end with it; one that breaks into a removal's words
        is a substitution there. A redirect's target is not an argument."""
        if self.depth > 4:
            raise Defer("nested too deep")
        subs, argv, skip, saved, backtick = [], [], False, [], False
        for kind, v in sh.lex(src, subs):
            if kind == "w":
                if skip:
                    skip = False
                else:
                    argv.append(v)
                continue
            if v in sh.SEPARATORS and argv:
                self.command(argv, cut=v in ("(", "`"))
                argv = []
            if v == "(" or (v == "`" and not backtick):
                saved.append((self.cwd, dict(self.vars)))
            elif (v == ")" or v == "`") and saved:
                self.cwd, self.vars = saved.pop()
            backtick ^= v == "`"
            skip = v not in sh.SEPARATORS
        if argv:
            self.command(argv, cut=False)
        # A trap runs when the shell exits, with the variables it ends with.
        for action in self.traps:
            Reading(self.cwd, self.vars, self.depth + 1).run(action)
        # Where a quoted substitution ran among the commands is not kept, so
        # it is read knowing no variable and no directory.
        for sub in subs:
            Reading(None, {}, self.depth + 1).run(sub)

    def command(self, argv, cut):
        env, argv = sh.strip_prefix(argv)
        if not argv:
            for k, v in env.items():
                self.assign(k + "=" + v)
            return
        name, args = os.path.basename(argv[0]), argv[1:]
        if APPEND.match(argv[0]):
            self.vars[argv[0].split("+=")[0]] = None
        elif name in DECLARERS:
            for a in args:
                if sh.ASSIGNMENT.match(a):
                    self.assign(a)
        elif name in REBINDERS:
            # Whatever these bind is known only at run time.
            for a in args:
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", a):
                    self.vars[a] = None
        elif name == "case":
            raise Defer("case, whose ) this reading does not follow")
        elif name in ("cd", "pushd"):
            self.change_dir([a for a in args if not a.startswith("-")])
        elif name in REMOVERS:
            if cut:
                raise Defer("a substitution inside the %s command" % name)
            self.removal(name, args)
        elif name in SHELLS:
            script = shell_script(args)
            if script is not None:
                Reading(self.cwd, {}, self.depth + 1).run(script)
        elif name == "trap":
            if args and not args[0].startswith("-"):
                self.traps.append(args[0])
        elif name == "eval":
            raise Defer("eval")
        elif name in ("xargs", "parallel", "find"):
            if "-delete" in args or any(os.path.basename(a) in REMOVERS for a in args):
                raise Defer("%s feeding a removal" % name)

    def change_dir(self, operands):
        target = self.expand(operands[0]) if operands else os.environ.get("HOME")
        if not target or target == "-":
            self.cwd = None
        elif os.path.isabs(target):
            self.cwd = os.path.normpath(target)
        elif self.cwd:
            self.cwd = os.path.normpath(os.path.join(self.cwd, target))

    def removal(self, name, args):
        targets, options = [], True
        for a in args:
            if options and a == "--":
                options = False
            elif options and a.startswith("-") and a != "-":
                continue
            else:
                targets.append(a)
        for t in targets:
            path = self.expand(t)
            if path is None:
                raise Defer("%s target %s cannot be resolved" % (name, t))
            if not os.path.isabs(path):
                if not self.cwd:
                    raise Defer("%s target %s is relative to an unknown directory" % (name, t))
                path = os.path.join(self.cwd, path)
            path = os.path.normpath(path) + ("/" if path.endswith("/") else "")
            if not safe_target(path):
                raise Defer("%s target %s is not below a temp directory" % (name, path))


def shell_script(args):
    """The string a shell runs with -c, or None."""
    for i, a in enumerate(args):
        if a.startswith("-") and not a.startswith("--") and "c" in a[1:]:
            rest = [x for x in args[i + 1:] if not x.startswith("-")]
            return rest[0] if rest else None
        if not a.startswith("-"):
            return None
    return None


def verdict(command):
    """None to approve, or why the prompt stays. A relative target counts
    only after an absolute cd in the command: the payload's cwd need not be
    the shell's."""
    try:
        Reading(None).run(command)
    except Defer as d:
        return str(d)
    return None


def log(entry):
    path = os.environ.get("CLAUDE_RM_PROMPTS_LOG", DEFAULT_LOG)
    if not path:
        return
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except OSError:
        pass


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    if payload.get("tool_name") != "Bash" or payload.get("permission_suggestions") != []:
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0
    try:
        reason = verdict(command)
    except Exception as e:  # a reading this hook got wrong is never an approval
        reason = "hook error: %r" % e
    log({"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "session": payload.get("session_id"),
         "approved": reason is None, "why": reason, "cwd": payload.get("cwd"), "command": command[:300]})
    if reason is None:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

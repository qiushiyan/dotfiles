#!/usr/bin/env python3
"""PreToolUse(Bash) hook: refuse git commands that destroy work or overwrite
remote history.

Policy: Claude may push any branch, force-with-lease and remote ref deletes
included; unconditional overwrites (--force, -f, +refspec, --mirror) and
work-destroying commands are refused, and `git branch -D` is gated behind a
per-command CLAUDE_ALLOW_BRANCH_DELETE=1.

The command is split the way the shell splits it, into simple commands on
; && || | & ( ) ` and newlines, and each git argv is judged whatever its flag
order. Quoted text (a "$(...)" included), heredoc bodies and comments stay
inert, so a commit message that mentions `git push --force` passes. Accident
prevention, not a sandbox: `bash -c "..."`, aliases and scripts are not looked
into. Exit 2 refuses (stderr goes to the model); unreadable input passes.
"""
import json
import os
import re
import sys

SEPARATORS = {";", "&", "&&", "|", "||", "|&", ";;", "(", ")", "`", "\n"}
OPERATORS = sorted(SEPARATORS | {
    "<", ">", ">>", "<&", ">&", ">|", "<>", "&>", "&>>", "<<<",
}, key=len, reverse=True)
# A digit-led word after << is arithmetic ($((1<<2))), not a delimiter.
HEREDOC = re.compile(r"<<(-?)[ \t]*(?:'([^'\n]*)'|\"([^\"\n]*)\"|\\?([^\s\d;&|()<>'\"`][^\s;&|()<>'\"`]*))")
# Words that may precede the command name without being it.
PREFIXES = {"if", "then", "elif", "else", "do", "while", "until", "!", "{",
            "time", "command", "builtin", "exec", "env", "nohup", "sudo"}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
# git's global options that take the next word as their value.
GIT_GLOBAL_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                  "--config-env", "--super-prefix", "--exec-path"}
WHOLE_TREE = {".", "./", ":/", ":/."}


def heredoc(src, i, pending):
    """At a heredoc opener (<<WORD, not <<<), queue its delimiter and return
    the index after it; otherwise None."""
    m = HEREDOC.match(src, i) if not src.startswith("<<<", i) else None
    if not m:
        return None
    pending.append((m.group(2) or m.group(3) or m.group(4) or "", m.group(1) == "-"))
    return m.end()


def skip_bodies(src, i, pending):
    """At the start of a line, skip the bodies of the pending heredocs."""
    for delim, strip_tabs in pending:
        while i < len(src):
            j = src.find("\n", i)
            j = len(src) if j < 0 else j
            line, i = src[i:j], j + 1
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                break
    pending.clear()
    return i


def skip_quoted(src, i):
    """From just inside a double quote, return the index after its close.
    A $(...) or `...` inside belongs to the string, with its own quoting and
    heredocs, so it is skipped as a unit."""
    n = len(src)
    while i < n and src[i] != '"':
        if src[i] == "\\":
            i += 2
        elif src.startswith("$(", i):
            i = skip_substitution(src, i + 2)
        elif src[i] == "`":
            j = src.find("`", i + 1)
            i = n if j < 0 else j + 1
        else:
            i += 1
    return i + 1


def skip_substitution(src, i):
    """From just inside $(, return the index after its matching )."""
    n, depth, pending = len(src), 1, []
    while i < n:
        c = src[i]
        if c == "\\":
            i += 2
        elif c == "'":
            j = src.find("'", i + 1)
            i = n if j < 0 else j + 1
        elif c == '"':
            i = skip_quoted(src, i + 1)
        elif c == "<" and (j := heredoc(src, i, pending)):
            i = j
        elif c == "\n":
            i = skip_bodies(src, i + 1, pending)
        else:
            depth += {"(": 1, ")": -1}.get(c, 0)
            i += 1
            if depth == 0:
                break
    return i


def lex(src):
    """Words and operators of a shell command line. Quotes are removed from a
    word; heredoc bodies and comments are dropped; a redirect's fd number (the
    2 in 2>&1) is not a word."""
    items, word, inword, pending = [], [], False, []
    i, n = 0, len(src)

    def flush():
        nonlocal word, inword
        if inword:
            items.append(("w", "".join(word)))
        word, inword = [], False

    while i < n:
        c = src[i]
        if c == "\\":
            if not src.startswith("\n", i + 1):     # \<newline> joins lines
                word.append(src[i + 1:i + 2]); inword = True
            i += 2
        elif c == "'":
            j = src.find("'", i + 1)
            j = n if j < 0 else j
            word.append(src[i + 1:j]); inword = True; i = j + 1
        elif c == '"':
            j = skip_quoted(src, i + 1)
            word.append(re.sub(r'\\([$`"\\])', r"\1", src[i + 1:j - 1])); inword = True; i = j
        elif c == "#" and not inword:
            j = src.find("\n", i)
            i = n if j < 0 else j                   # comment; keep the newline
        elif c in " \t":
            flush(); i += 1
        elif c == "<" and (j := heredoc(src, i, pending)):
            flush(); i = j
        elif c in ";&|()<>`\n":
            op = next(o for o in OPERATORS if src.startswith(o, i))
            if op not in SEPARATORS and inword and "".join(word).isdigit():
                word, inword = [], False            # fd number of a redirect
            flush()
            items.append(("op", op)); i += len(op)
            if op == "\n":
                i = skip_bodies(src, i, pending)
        else:
            word.append(c); inword = True; i += 1
    flush()
    return items


def simple_commands(items):
    """The argv of each simple command; a redirect's target is not an argument."""
    argv, skip = [], False
    for kind, v in items:
        if kind == "op":
            if v in SEPARATORS and argv:
                yield argv
                argv = []
            skip = v not in SEPARATORS
        elif skip:
            skip = False
        else:
            argv.append(v)
    if argv:
        yield argv


def strip_prefix(argv):
    """Drop keywords, wrappers and VAR=value prefixes; return (env, argv)."""
    env, i, wrapper = {}, 0, False
    while i < len(argv):
        w = argv[i]
        if ASSIGNMENT.match(w):
            k, _, v = w.partition("=")
            env[k] = v
        elif w in PREFIXES:
            wrapper = w in ("env", "sudo")
        elif not (wrapper and w.startswith("-")):
            break
        i += 1
    return env, argv[i:]


def is_long(arg, name):
    """`arg` spells long option `name`; git accepts any unique prefix."""
    opt = arg.split("=", 1)[0]
    return len(opt) > 3 and name.startswith(opt)


def short_flags(args, takes_value=""):
    """Letters of the short-option clusters in `args` (-fu gives f and u). A
    letter in `takes_value` ends its cluster: the rest of the word is its value."""
    letters = set()
    for a in args:
        if a.startswith("-") and not a.startswith("--"):
            for ch in a[1:]:
                letters.add(ch)
                if ch in takes_value:
                    break
    return letters


def judge(sub, args):
    """(kind, label) when `git <sub> <args>` is refused, else None."""
    if "--" in args:
        k = args.index("--")
        opts, paths = args[:k], args[k + 1:]
    else:
        opts, paths = args, args
    longs = lambda name: any(is_long(a, name) for a in opts)  # noqa: E731
    if sub == "push":
        if longs("--force") or longs("--mirror") or "f" in short_flags(opts, "o"):
            return "force", None
        if any(a.startswith("+") for a in args):
            return "force", None
    elif sub == "reset" and longs("--hard"):
        return "destroy", "git reset --hard"
    elif sub == "clean" and (longs("--force") or "f" in short_flags(opts, "e")):
        return "destroy", "git clean -f"
    elif sub in ("checkout", "restore") and WHOLE_TREE & set(paths):
        flags = short_flags(opts, "s")
        unstage_only = (longs("--staged") or "S" in flags) and not (longs("--worktree") or "W" in flags)
        if sub == "checkout" or not unstage_only:
            return "destroy", f"git {sub} ."
    elif sub == "branch":
        flags = short_flags(opts, "u")
        if "D" in flags or ((longs("--delete") or "d" in flags) and (longs("--force") or "f" in flags)):
            return "branch-delete", None
    return None


def verdict(command):
    for argv in simple_commands(lex(command)):
        env, argv = strip_prefix(argv)
        if not argv or os.path.basename(argv[0]) != "git":
            continue
        args, i = argv[1:], 0
        while i < len(args) and args[i].startswith("-"):
            i += 2 if args[i] in GIT_GLOBAL_ARG else 1
        hit = judge(args[i], args[i + 1:]) if i < len(args) else None
        if hit and not (hit[0] == "branch-delete" and env.get("CLAUDE_ALLOW_BRANCH_DELETE") == "1"):
            return hit
    return None


FORCE_MSG = """\
BLOCKED: '{cmd}' is a force or mirror push.

These are NEVER bypassable from inside Claude — they overwrite remote history
unconditionally. To update a branch you rewrote, push with --force-with-lease
instead of --force, -f or a +refspec: it is allowed, and it refuses when the
remote has moved since you last fetched. A mirror push the user must run
manually after deciding the operation is intentional.
"""

DESTROY_MSG = ("BLOCKED: '{cmd}' matches dangerous pattern '{label}'. "
               "The user has prevented you from doing this.\n")

BRANCH_MSG = """\
BLOCKED: git branch -D force-deletes a branch, which is gated.

Deleting a branch git still considers unmerged can drop commits that exist
nowhere else. This is the expected state — not an error to work around.

How to bypass when authorized:

  CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D <branch>

When to use the bypass:
- ONLY when the user has authorized this cleanup — "clean up the worktrees",
  "delete that branch", or a cleanup task they asked for.
- Prefer `git branch -d` first. It succeeds whenever git can see the work is
  merged, and its refusal is the signal that this gate exists for.

When NOT to use the bypass:
- On your own initiative after deciding a branch looks finished.
- To clear an error from `git branch -d` you have not explained. Confirm the
  work reached the trunk first: for a squash merge, that the merged PR's head
  equals or contains this branch's HEAD.

If unsure: report the branch and why `-d` refused, then let the user decide.
"""


def main():
    try:
        command = json.load(sys.stdin)["tool_input"]["command"]
    except Exception:
        return 0
    hit = verdict(command) if isinstance(command, str) else None
    if not hit:
        return 0
    kind, label = hit
    msg = {"force": FORCE_MSG, "destroy": DESTROY_MSG, "branch-delete": BRANCH_MSG}[kind]
    sys.stderr.write(msg.format(cmd=command, label=label))
    return 2


if __name__ == "__main__":
    sys.exit(main())

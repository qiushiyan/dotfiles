#!/usr/bin/env python3
"""PreToolUse(Bash) hook: refuse git commands that destroy work or overwrite
remote history.

Policy: Claude may push any branch, force-with-lease and remote ref deletes
included; unconditional overwrites (--force, -f, +refspec, --mirror) and
work-destroying commands are refused, and `git branch -D` is gated behind a
per-command CLAUDE_ALLOW_BRANCH_DELETE=1. Work-destroying means reset --hard,
clean -f, a forced checkout or switch, and a checkout or worktree restore of a
whole-tree pathspec (`.`, `..`, `*`, `:/`, `:(top)` and their spellings).

The command is split the way the shell splits it, into simple commands on
; && || | & ( ) ` and newlines, and each git argv is judged whatever its flag
order, behind keywords, VAR=value prefixes and precommand wrappers (env, sudo,
nice, timeout, exec, ...) with their options and operands. A command
substitution runs wherever the shell expands it, so one inside a double-quoted
string or an unquoted heredoc body is judged too. The rest of quoted text,
quoted heredoc bodies (<<'EOF') and comments stay inert, so a commit message
that mentions `git push --force` passes.

Accident prevention, not a sandbox. Out of scope, because the text that runs
is decided by another program or at run time: strings handed to another
interpreter (bash -c, eval, env -S, ssh, watch), xargs and find -exec,
aliases, functions, scripts, git aliases, commands or pathspecs held in
variables or files, and a pathspec that names the repository root by its
absolute path. Exit 2 refuses (stderr goes to the model); unreadable input
passes.
"""
import json
import os
import re
import sys

SEPARATORS = {";", "&", "&&", "|", "||", "|&", ";;", "(", ")", "`", "\n"}
OPERATORS = sorted(SEPARATORS | {
    "<", ">", ">>", "<&", ">&", ">|", "<>", "&>", "&>>", "<<<",
}, key=len, reverse=True)
WORD_END = " \t\n;&|()<>`"
KEYWORDS = {"if", "then", "elif", "else", "do", "while", "until", "!", "{"}
# Precommand wrappers that run the rest of their argv: (short options and long
# options that take the next word as their value, operands before the command).
WRAPPERS = {
    "command": ("", (), 0), "builtin": ("", (), 0), "nohup": ("", (), 0),
    "noglob": ("", (), 0), "nocorrect": ("", (), 0),
    "exec": ("a", (), 0),
    "time": ("fo", ("--format", "--output"), 0),
    "env": ("CPSu", ("--chdir", "--split-string", "--unset"), 0),
    "sudo": ("CDgprTtUu", ("--chdir", "--chroot", "--close-from", "--command-timeout",
                           "--group", "--host", "--other-user", "--prompt", "--role",
                           "--type", "--user"), 0),
    "doas": ("Cu", (), 0),
    "nice": ("n", ("--adjustment",), 0),
    "timeout": ("ks", ("--kill-after", "--signal"), 1),
    "gtimeout": ("ks", ("--kill-after", "--signal"), 1),
    "stdbuf": ("eio", ("--error", "--input", "--output"), 0),
    "caffeinate": ("tw", (), 0),
}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
# git's global options that take the next word as their value.
GIT_GLOBAL_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                  "--config-env", "--super-prefix", "--exec-path"}


def heredoc(src, i, pending):
    """At a heredoc opener (<<WORD, not <<<), queue (delimiter, strip tabs,
    body expands) and return the index after the word; otherwise None. Any
    quoting in the word makes the body literal."""
    if not src.startswith("<<", i) or src.startswith("<<<", i):
        return None
    n, j = len(src), i + 2
    strip = src.startswith("-", j)
    j += strip
    while j < n and src[j] in " \t":
        j += 1
    if j == n or src[j].isdigit():          # $((1<<2)) is arithmetic
        return None
    start, word, quoted = j, [], False
    while j < n and src[j] not in WORD_END:
        c = src[j]
        if c in "'\"":
            k = src.find(c, j + 1)
            k = n if k < 0 else k
            word.append(src[j + 1:k]); quoted = True; j = k + 1
        elif c == "\\":
            word.append(src[j + 1:j + 2]); quoted = True; j += 2
        else:
            word.append(c); j += 1
    if j == start:
        return None
    pending.append(("".join(word), strip, not quoted))
    return min(j, n)


def skip_bodies(src, i, pending, subs):
    """At the start of a line, skip the bodies of the pending heredocs. The
    command substitutions of an expanding body go to `subs` (unless None)."""
    n = len(src)
    for delim, strip_tabs, expands in pending:
        start = end = i
        while i < n:
            j = src.find("\n", i)
            j = n if j < 0 else j
            line, end, i = src[i:j], i, j + 1
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                break
        else:
            end = n
        if expands and subs is not None:
            expansions(src[start:end], 0, None, subs)
    pending.clear()
    return i


def expansions(src, i, stop, subs):
    """Scan expanding text from i: a double-quoted string's inside when `stop`
    is '"', a heredoc body when it is None. Return the index after `stop`. The
    source of each $(...) and `...` goes to `subs` (unless None)."""
    n = len(src)
    while i < n and src[i] != stop:
        if src[i] == "\\":
            i += 2
        elif src.startswith("$(", i):
            j = skip_substitution(src, i + 2)
            if subs is not None:
                subs.append(src[i + 2:j - 1] if src[j - 1:j] == ")" else src[i + 2:j])
            i = j
        elif src[i] == "`":
            j = i + 1
            while j < n and src[j] != "`":
                j += 2 if src[j] == "\\" else 1
            if subs is not None:
                subs.append(re.sub(r'\\([\\`$"])', r"\1", src[i + 1:j]))
            i = j + 1
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
            i = expansions(src, i + 1, '"', None)
        elif c == "<" and (j := heredoc(src, i, pending)):
            i = j
        elif c == "\n":
            i = skip_bodies(src, i + 1, pending, None)
        else:
            depth += {"(": 1, ")": -1}.get(c, 0)
            i += 1
            if depth == 0:
                break
    return min(i, n)


def lex(src, subs):
    """Words and operators of a shell command line. Quotes are removed from a
    word; heredoc bodies and comments are dropped; a redirect's fd number (the
    2 in 2>&1) is not a word. The source of each command substitution inside
    a double-quoted word or an expanding heredoc body goes to `subs`; one in
    plain text is lexed in place, its ( ) and ` being separators."""
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
            j = expansions(src, i + 1, '"', subs)
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
                i = skip_bodies(src, i, pending, subs)
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


def commands(src):
    """The argv of every simple command `src` runs, substitutions included."""
    subs = []
    yield from simple_commands(lex(src, subs))
    for sub in subs:
        yield from commands(sub)


def skip_options(argv, i, short_values, long_values, operands):
    """Index of the command a wrapper runs: past the options from argv[i]
    (with the values they take), then past `operands` operands."""
    while i < len(argv) and argv[i].startswith("-"):
        a = argv[i]
        i += 1
        if a == "--":
            break
        if a.startswith("--"):
            i += "=" not in a and any(is_long(a, o) for o in long_values)
        else:
            for k, ch in enumerate(a[1:], 2):
                if ch in short_values:
                    i += k == len(a)                # value is the next word
                    break
    return i + operands


def strip_prefix(argv):
    """Drop keywords, VAR=value prefixes and wrappers; return (env, argv)."""
    env, i = {}, 0
    while i < len(argv):
        w = argv[i]
        if ASSIGNMENT.match(w):
            k, _, v = w.partition("=")
            env[k] = v
            i += 1
        elif w in KEYWORDS:
            i += 1
        elif w in WRAPPERS:
            i = skip_options(argv, i + 1, *WRAPPERS[w])
        else:
            break
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


def whole_tree(spec):
    """The pathspec covers the whole tree, or all of the current directory:
    `.`, `..`, `*`, `:/`, `:(top)` and their spellings. An exclusion (`:!x`,
    `:(exclude)x`) covers nothing."""
    if spec.startswith(":("):
        magic, _, spec = spec[2:].partition(")")
        if "exclude" in magic.split(","):
            return False
    elif spec.startswith(":"):
        k = 1
        while spec[k:k + 1] in ("/", "!", "^"):
            k += 1
        if "!" in spec[1:k] or "^" in spec[1:k]:
            return False
        spec = spec[k + (spec[k:k + 1] == ":"):]
    return all(part in ("", ".", "..", "*", "**") for part in spec.split("/"))


def judge(sub, args):
    """(kind, label) when `git <sub> <args>` is refused, else None."""
    if "--" in args:
        k = args.index("--")
        opts, paths = args[:k], args[k + 1:]
    else:
        opts, paths = args, [a for a in args if not a.startswith("-")]
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
    elif sub == "switch":
        if longs("--discard-changes") or longs("--force") or "f" in short_flags(opts, "cC"):
            return "destroy", "git switch --discard-changes"
    elif sub in ("checkout", "restore"):
        # Without --, a forced checkout's operand may be a branch: a forced
        # switch discards every local change.
        if sub == "checkout" and "--" not in args and (longs("--force") or "f" in short_flags(opts, "bB")):
            return "destroy", "git checkout --force"
        flags = short_flags(opts, "s")
        unstage_only = (longs("--staged") or "S" in flags) and not (longs("--worktree") or "W" in flags)
        if sub == "restore" and unstage_only:
            return None
        for p in paths:
            if whole_tree(p):
                return "destroy", f"git {sub} {p}"
    elif sub == "branch":
        flags = short_flags(opts, "u")
        if "D" in flags or ((longs("--delete") or "d" in flags) and (longs("--force") or "f" in flags)):
            return "branch-delete", None
    return None


def verdict(command):
    for argv in commands(command):
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

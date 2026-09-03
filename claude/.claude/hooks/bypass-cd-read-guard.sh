#!/bin/bash
# PreToolUse(Bash) — bypass-mode sessions only.
#
# Claude Code 2.1.259 added a Bash safety check: while any `Read(...)` deny
# rule is loaded (the planlab repo commits `Read(./.env)`), a command that
# does `cd DIR` and later greps/rgs/diffs/gits/cps/mvs a RELATIVE path stops
# for a human "only you can approve" prompt — in bypass mode too, and a
# PreToolUse `allow` cannot clear it. The analyzer follows the cwd only
# through an unbroken `&&` chain: `cd DIR && grep x rel` is fine, while
# `cd DIR; grep x rel`, a newline, `|`, `||`, or `cd DIR && ls; grep x rel`
# all ask (probed 2026-09-03, docs/bypass-cd-read-guard.md). Nobody watches
# an `x` session for prompts, so the session just stalls.
#
# This guard refuses exactly that shape *before* Claude Code sees it, with a
# message that tells the model the smallest rewrite (`&&`). A deny costs one
# retry; a silent rewrite (updatedInput) was rejected because a stripped or
# re-joined `cd` is not provably inert and the transcript would then show a
# command that never ran. Outside bypass mode this hook does nothing: a
# prompted session can answer the prompt, and the deny rule is doing its
# job there.
#
# Heuristic, not a parser — false positives cost a retry, false negatives
# cost a stalled session, so it leans toward denying.

INPUT=$(cat)
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // empty') || exit 0
[ "$MODE" = "bypassPermissions" ] || exit 0
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty') || exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$COMMAND" ] || exit 0

# Fast path: no `cd` word at all → nothing to do.
printf '%s' "$COMMAND" | grep -qE '(^|[;&|[:space:]({])cd([[:space:]]|$)' || exit 0

VERDICT=$(printf '%s' "$COMMAND" | CWD="$CWD" python3 -c '
import os, re, sys, shlex
cmd = sys.stdin.read(); cwd = os.environ.get("CWD", "")
READERS = {"grep", "egrep", "fgrep", "rg", "diff", "git", "cp", "mv"}

# Drop heredoc bodies, then split into simple commands on ; && || | & ( ) and
# newlines — quote-aware, so a `;` inside a commit message or a quoted prompt
# never opens a segment. A line whose quotes stay open is joined with the next.
lines, kept, term = cmd.split("\n"), [], None
for ln in lines:
    if term is not None:
        if ln.strip() == term: term = None
        continue
    m = re.search(r"<<-?\s*[\x27\"]?([A-Za-z_][A-Za-z0-9_]*)", ln)
    if m: term = m.group(1)
    kept.append(ln)
segments, buf = [], ""
for ln in kept:
    buf = (buf + "\n" + ln) if buf else ln
    try:
        lex = shlex.shlex(buf, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        toks = list(lex)
    except ValueError:
        continue          # unbalanced quote: the string spans lines, keep accumulating
    buf = ""
    seg, skip, sep = [], False, "\n"     # a line break separates like `;`
    for t in toks:
        if skip: skip = False; continue          # redirect target
        if t and set(t) <= set(";|&()"):
            if seg: segments.append((sep, seg))
            seg, sep = [], t
        elif t and set(t) <= set("<>"):
            skip = True
        else:
            seg.append(t)
    if seg: segments.append((sep, seg))
if buf:
    sys.exit(0)           # never balanced: give up, fail open

# The analyzer tracks the cwd only along an unbroken `&&` chain from the cd.
seen_cd, chain_broken, cd_target = False, False, None
for sep, words in segments:
    if seen_cd and sep != "&&": chain_broken = True
    # skip leading VAR=value assignments
    while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]): words = words[1:]
    if not words: continue
    exe = os.path.basename(words[0])
    if exe == "cd":
        seen_cd = True
        cd_target = words[1] if len(words) > 1 and not words[1].startswith("-") else None
        continue
    if not (seen_cd and chain_broken) or exe not in READERS: continue
    args = words[1:]
    if exe == "git":
        # only pathspecs matter: words after `--`, or ones that look like paths
        if "--" in args:
            rest = args[args.index("--") + 1:]
        else:
            rest, prev = [], None
            for a in args[1:]:
                if prev in ("-m", "--message", "-F", "--file", "-C", "--author"): prev = a; continue
                if ("/" in a or "." in a) and not re.search(r"\s", a): rest.append(a)
                prev = a
    elif exe in ("grep", "egrep", "fgrep", "rg"):
        rest = [a for a in args if not a.startswith("-")]
        if not any(a in ("-e", "--regexp", "-f", "--file") or a.startswith(("-e", "--regexp=", "-f")) for a in args):
            rest = rest[1:]   # first bare operand is the pattern
    else:
        rest = [a for a in args if not a.startswith("-")]
    for a in rest:
        if a in ("", "-") or a.startswith(("/", "~", "$")): continue
        tgt = cd_target or ""
        print(exe + "\t" + a + "\t" + tgt); sys.exit(0)
') || exit 0
[ -n "$VERDICT" ] || exit 0

IFS=$'\t' read -r EXE OPERAND TARGET <<<"$VERDICT"
if [ -n "$TARGET" ] && [ "${TARGET%/}" = "${CWD%/}" ]; then
  HOW="Drop the \`cd\` — the shell is already in $CWD — and re-run the rest unchanged."
else
  HOW="Re-issue it as one \`&&\` chain from the cd (\`cd DIR && ... && $EXE ...\`), or use absolute paths / \`git -C <dir>\`."
fi
cat >&2 <<MSG
BLOCKED by the bypass-mode cd guard: this command does a \`cd\` and, after a \`;\`, newline, \`|\` or \`||\`, \`$EXE\` reads the relative path '$OPERAND'.
Claude Code only tracks the directory through an unbroken \`&&\` chain; anything else stops for a human approval that no one is watching in this session.
$HOW
(Applies to grep, egrep, fgrep, rg, diff, git, cp, mv.)
MSG
exit 2

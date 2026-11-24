#!/usr/bin/env python3
"""UserPromptSubmit hook: stop a message whose slash command was pasted, so
it is not sent to the model as text.

Claude Code collapses a paste past 800 characters or of three or more lines
into a `[Pasted text #N +M lines]` placeholder, and a command that appears
only once that placeholder is expanded is never run: the message goes to the
model wrapped as pasted content, and the session improvises the skill from
its files or answers the text (anthropics/claude-code#85654, #86803). Pasting
the same text again expands the placeholder in the input box, and Enter then
runs the command.

What the hook is given for such a message was read from Claude Code 2.1.331:
`\\n\\n<pasted_content id="d61f">\\n/strategic-review 999\\n…`. A blocked
message stays in the input box, so the reason tells the person to paste
again there. The `Pasted text:\\n/…` form is what Claude Code sends when its
paste tagging is off; it was read from the code, not seen live.

The first line must name a command this session has, so a pasted listing
that starts with `/tmp` passes: a skill folder or a command file in the
project's and the account's `.claude`, `~/.claude` or `~/.agents/skills`, a
plugin's `name:command`, or one of Claude Code's built-in commands that take
words after them. Text typed before the paste passes too, since the person
wrote a message rather than a command. Any failure lets the message through.
"""
import json
import os
import re
import subprocess
import sys

OPENERS = (
    re.compile(r'<pasted_content id="[0-9a-f]+">\n'),
    re.compile(r"Pasted text:\n"),
)
COMMAND = re.compile(r"/([A-Za-z0-9_][A-Za-z0-9:_-]*)(?=\s|$)")
BUILT_IN = {
    "add-dir", "btw", "compact", "context", "effort", "export", "goal",
    "init", "loop", "memory", "model", "plan", "rename", "resume",
    "ultraplan", "ultrareview",
}


def pasted_command(prompt):
    """The command a pasted block opens with, "" when it opens with none."""
    text = prompt.lstrip()
    for opener in OPENERS:
        head = opener.match(text)
        if head:
            found = COMMAND.match(text, head.end())
            return found.group(1) if found else ""
    return ""


def git_top(cwd):
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def known(name, cwd):
    if ":" in name or name in BUILT_IN:
        return True
    home = os.path.expanduser("~")
    bases = []
    if cwd:
        bases.append(os.path.join(cwd, ".claude"))
        top = git_top(cwd)
        if top:
            bases.append(os.path.join(top, ".claude"))
    config = os.environ.get("CLAUDE_CONFIG_DIR", "")
    if config:
        bases.append(config)
    bases.append(os.path.join(home, ".claude"))
    for base in bases:
        if os.path.isfile(os.path.join(base, "skills", name, "SKILL.md")):
            return True
        if os.path.isfile(os.path.join(base, "commands", name + ".md")):
            return True
    return os.path.isfile(os.path.join(home, ".agents", "skills", name, "SKILL.md"))


def main():
    try:
        event = json.load(sys.stdin)
        name = pasted_command(event.get("prompt") or "")
        if not name or not known(name, event.get("cwd") or ""):
            return
    except Exception:
        return
    print(json.dumps({
        "decision": "block",
        "reason": (
            "Not sent: /%s was pasted, and Claude Code sends a pasted command "
            "to the model as text instead of running it. Paste the same text "
            "again to expand it in the input box, then press Enter." % name
        ),
    }))


if __name__ == "__main__":
    main()

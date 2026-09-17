#!/usr/bin/env python3
"""Copy a completed Zsh command and its displayed tmux output."""

import argparse
import subprocess
import sys


def tmux(*args):
    return subprocess.run(
        ["tmux", *args], check=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True,
    ).stdout


def transcript(command, skipped, capture):
    rows = [line.partition(" ")[::2] for line in capture.removesuffix("\n").split("\n")]
    prompts = [i for i, (flags, _) in enumerate(rows) if "P" in flags]
    if len(prompts) < skipped + 2:
        raise ValueError("command boundaries are missing or have left scrollback; run a new command.")
    start, end = prompts[-skipped - 2], prompts[-skipped - 1]
    output = next((i for i in range(start + 1, end) if "O" in rows[i][0]), end)
    # Without an output mark the command was silent. In that case tmux's O
    # flag was on the next prompt's row and disappeared when it was redrawn.
    chunks = []
    for flags, text in rows[output:end]:
        chunks.append(text)
        if "W" not in flags:
            chunks.append("\n")
    return "$ " + command + "\n" + "".join(chunks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pane", required=True)
    parser.add_argument("--print", action="store_true", help="print without changing the clipboard")
    parser.add_argument("--notify", action="store_true", help="report through the tmux status line")
    args = parser.parse_args()
    try:
        ready = tmux("show-options", "-pqv", "-t", args.pane, "@cout-ready").strip()
        if ready != "1":
            raise ValueError("no completed command is ready; open a new shell and run a command first.")
        command = tmux("show-options", "-pqv", "-t", args.pane, "@cout-command").removesuffix("\n")
        skipped = int(tmux("show-options", "-pqv", "-t", args.pane, "@cout-skip").strip())
        capture = tmux("capture-pane", "-p", "-F", "-T", "-N", "-S", "-", "-t", args.pane)
        text = transcript(command, skipped, capture)
        if args.print:
            sys.stdout.write(text)
        else:
            subprocess.run(["pbcopy"], input=text, text=True, check=True)
            if args.notify:
                tmux("display-message", "-t", args.pane, "Copied command and output")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        message = f"cout: {error}"
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            message = f"cout: {error.stderr.strip()}"
        if args.notify:
            tmux("display-message", "-t", args.pane, message)
        else:
            print(message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Record completed shell executions and copy their terminal transcripts."""

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


MAX_RECORD = 16 * 1024 * 1024
MAX_CACHE = 64 * 1024 * 1024
MAX_RECORDS = 1000
RECORD_ID = re.compile(r"[0-9a-f]{32}-[1-9][0-9]*\Z")


def tmux(*args):
    return subprocess.run(["tmux", *args], check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True).stdout


def option(pane, name):
    return tmux("show-options", "-pqv", "-t", pane, name).removesuffix("\n")


def atomic_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False))
    temporary.replace(path)


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def prepare(pane):
    """Attach one recorder without replacing somebody else's pipe-pane logger."""
    root = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "cout"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(root, 0o700)
    existing = option(pane, "@cout-store")
    piped = tmux("display-message", "-p", "-t", pane, "#{pane_pipe}").strip() == "1"
    if piped:
        store = Path(existing) if existing else None
        if not store or not (store / "recorder.json").is_file():
            raise ValueError("this pane already has an output pipe; cout did not replace it.")
        if not alive(json.loads((store / "recorder.json").read_text())["pid"]):
            raise ValueError("the pane's output pipe is not a live cout recorder.")
    else:
        # Reap only our own abandoned directories after a server/recorder crash.
        for stale in root.glob("pane-*"):
            manifest = stale / "recorder.json"
            if stale.is_symlink() or not manifest.is_file():
                continue
            if not alive(json.loads(manifest.read_text())["pid"]):
                shutil.rmtree(stale)
        store = Path(tempfile.mkdtemp(prefix="pane-", dir=root))
        command = shlex.join([sys.executable, str(Path(__file__).resolve()), "record", str(store)])
        tmux("pipe-pane", "-O", "-t", pane, "exec " + command.replace("#", "##"))
        deadline = time.monotonic() + 3
        while not (store / "recorder.json").exists():
            if time.monotonic() >= deadline:
                raise ValueError("the pane recorder did not start; run zshreload to retry.")
            time.sleep(.01)
    tmux("set-option", "-p", "-t", pane, "@cout-store", str(store), ";",
         "set-option", "-p", "-t", pane, "@cout-ready", "0")
    print(store)
    print(secrets.token_hex(16))


class Recorder:
    """The only writer of the session indexes and bounded output records."""

    def __init__(self, store):
        self.store = store
        self.active = {}
        self.sessions = {}
        self.index = {}
        self.completed = []
        self.total = 0

    def output(self, data):
        # A parent command such as `zsh`/`ssh` owns the whole nested interaction.
        for record in self.active.values():
            if record["size"] + len(data) > MAX_RECORD:
                record["error"] = "output exceeds the 16 MiB per-command recording limit."
            elif not record.get("error"):
                record["file"].write(data)
                record["size"] += len(data)

    def finish(self, identity, error=None):
        record = self.active.pop(identity, None)
        if record is None:
            return
        record.pop("file").close()
        if error:
            record["error"] = error
        session = identity.split("-")[0]
        self.index.setdefault(session, []).insert(0, identity)
        self.completed.append(identity)
        self.total += record["size"]
        atomic_json(self.store / f"{identity}.json", record)
        while len(self.completed) > MAX_RECORDS or self.total > MAX_CACHE:
            oldest = self.completed.pop(0)
            metadata = json.loads((self.store / f"{oldest}.json").read_text())
            self.total -= metadata["size"]
            ids = self.index[oldest.split("-")[0]]
            ids.remove(oldest)
            if not ids:
                del self.index[oldest.split("-")[0]]
            for suffix in ("json", "raw", "command"):
                (self.store / f"{oldest}.{suffix}").unlink()
        atomic_json(self.store / "index.json", self.index)

    def marker(self, frame):
        parts = frame.decode("ascii").split(";")
        if len(parts) == 3 and parts[0] == "S" and re.fullmatch(r"[0-9a-f]{32}", parts[1]):
            session, pid = parts[1], int(parts[2])
            prior = self.sessions.get(pid)
            # exec zsh replaces a shell without running its exit hook.
            for identity in list(self.active):
                if identity.startswith(f"{prior}-"):
                    self.finish(identity, "shell was replaced before this command finished.")
            self.sessions[pid] = session
        elif len(parts) == 4 and parts[0] == "B" and RECORD_ID.fullmatch(parts[1]):
            identity = parts[1]
            if identity in self.active or not (self.store / f"{identity}.command").is_file():
                raise ValueError("invalid command start")
            self.active[identity] = {
                "columns": max(1, min(4096, int(parts[2]))),
                "rows": max(2, min(512, int(parts[3]))),
                "size": 0,
                "file": (self.store / f"{identity}.raw").open("wb"),
            }
        elif len(parts) == 2 and parts[0] == "E" and RECORD_ID.fullmatch(parts[1]):
            self.finish(parts[1])
        else:
            raise ValueError("invalid recorder marker")

    def run(self):
        prefix = b"\x1b]777;cout;" + self.store.name.encode() + b";"
        pending = b""
        while data := os.read(0, 65536):
            pending += data
            while pending:
                start = pending.find(prefix)
                if start < 0:
                    # Keep only a possible partial prefix across read boundaries.
                    keep = min(len(prefix) - 1, len(pending))
                    self.output(pending[:-keep] if keep else pending)
                    pending = pending[-keep:] if keep else b""
                    break
                self.output(pending[:start])
                pending = pending[start:]
                end = pending.find(b"\x07", len(prefix))
                if end < 0:
                    if len(pending) > 512:
                        raise ValueError("oversized recorder marker")
                    break
                self.marker(pending[len(prefix):end])
                pending = pending[end + 1:]


def record(store):
    os.umask(0o077)
    recorder = Recorder(store)
    atomic_json(store / "recorder.json", {"pid": os.getpid()})
    try:
        recorder.run()
    finally:
        for entry in recorder.active.values():
            entry["file"].close()
        shutil.rmtree(store, ignore_errors=True)


def render(raw, metadata):
    """Replay bytes into an isolated terminal emulator, never into the live pane."""
    data = raw.read_bytes()
    if re.search(rb"\x1b\[\?(?:[0-9]*;)*0*(?:47|1047|1049)(?:;[0-9]*)*h", data):
        raise ValueError("full-screen applications do not have a plain command transcript.")
    with tempfile.TemporaryDirectory(prefix="cout-render-") as directory:
        tmp = Path(directory)
        # A private copy prevents retention cleanup racing the replay process.
        (tmp / "output").write_bytes(data)
        (tmp / "tmux.conf").write_text(
            "set -g default-shell /bin/sh\nset -g history-limit 100000\n"
            "set -g set-clipboard off\nset -g allow-passthrough off\nset -g status off\n")
        env = dict(os.environ, HOME=directory, ZDOTDIR=directory)
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        socket = str(tmp / "socket")
        first, last = "COUTBEGIN" + secrets.token_hex(16), "COUTEND" + secrets.token_hex(16)

        def terminal(*args):
            return subprocess.run(["tmux", "-S", socket, *args], env=env, check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout

        command = "exec " + shlex.join([sys.executable, str(Path(__file__).resolve()),
                                        "replay", str(tmp / "output"), first, last])
        try:
            terminal("-f", str(tmp / "tmux.conf"), "new-session", "-d", "-s", "render",
                     "-x", str(metadata["columns"]), "-y", str(metadata["rows"]), command)
            deadline = time.monotonic() + 5
            while True:
                screen = terminal("capture-pane", "-p", "-J", "-N", "-S", "-", "-t", "render:0")
                if last in screen:
                    if first + "\n" not in screen:
                        raise ValueError("output cleared the screen or exceeded the rendering history limit.")
                    output = screen.split(first + "\n", 1)[1].split(last, 1)[0].removesuffix("\n")
                    # Zsh's PROMPT_SP fills the next prompt row with spaces.
                    # Remove only that final empty row, preserving output's
                    # own trailing spaces and blank lines before it.
                    output = re.sub(r"(?m)^[ \t]+\Z", "", output)
                    return output + ("\n" if output and not output.endswith("\n") else "")
                if time.monotonic() >= deadline:
                    raise ValueError("terminal rendering did not finish; clipboard unchanged.")
                time.sleep(.02)
        finally:
            subprocess.run(["tmux", "-S", socket, "kill-server"], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def completed(pane, index):
    if option(pane, "@cout-ready") != "1":
        raise ValueError("no completed command is ready; open a new shell and run a command first.")
    state = option(pane, "@cout-state")
    store_name = option(pane, "@cout-store")
    if not state or not store_name:
        raise ValueError("run zshreload to enable command recording.")
    session, latest = state.split()
    if latest == "-":
        raise ValueError("no completed command is ready in this shell.")
    store = Path(store_name)
    deadline = time.monotonic() + 3
    while True:
        if not (store / "recorder.json").exists():
            raise ValueError("the command recorder stopped; run zshreload.")
        ids = json.loads((store / "index.json").read_text()).get(session, []) if (store / "index.json").exists() else []
        if ids and ids[0] == latest:
            break
        if time.monotonic() >= deadline:
            raise ValueError("the command recording is not complete; try again or run zshreload.")
        time.sleep(.01)
    if index > len(ids):
        raise ValueError(f"index {index} is unavailable; {len(ids)} command(s) retained in this shell.")
    identity = ids[index - 1]
    metadata = json.loads((store / f"{identity}.json").read_text())
    if metadata.get("error"):
        raise ValueError(metadata["error"])
    command = (store / f"{identity}.command").read_text()
    output = render(store / f"{identity}.raw", metadata)
    if option(pane, "@cout-state") != state or option(pane, "@cout-ready") != "1":
        raise ValueError("the active command changed while copying; try again.")
    return command, "$ " + command + "\n" + output


def copied_message(command):
    preview = " ".join("".join(c if c.isprintable() else " " for c in command).split())
    if len(preview) > 40:
        preview = preview[:40] + "…"
    return f'Copied "{preview}"'


def main():
    if sys.argv[1:2] == ["record"]:
        record(Path(sys.argv[2]))
        return 0
    if sys.argv[1:2] == ["replay"]:
        sys.stdout.buffer.write(sys.argv[3].encode() + b"\r\n" + Path(sys.argv[2]).read_bytes()
                                + b"\r\n\x1b[0m" + sys.argv[4].encode())
        sys.stdout.buffer.flush()
        time.sleep(30)  # The copy process kills this private server after capture.
        return 0
    setup = sys.argv[1:2] == ["setup"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pane", required=True)
    parser.add_argument("--index", type=int, default=1)
    parser.add_argument("--print", action="store_true", help="print without changing the clipboard")
    parser.add_argument("--notify", action="store_true", help="report through the tmux status line")
    args = parser.parse_args(sys.argv[2:] if setup else None)
    try:
        if setup:
            prepare(args.pane)
            return 0
        if args.index < 1:
            raise ValueError("index must be a positive integer.")
        command, text = completed(args.pane, args.index)
        if args.print:
            sys.stdout.write(text)
        else:
            subprocess.run(["pbcopy"], input=text, text=True, check=True)
            if args.notify:
                tmux("display-message", "-l", "-t", args.pane, copied_message(command))
            else:
                print(copied_message(command))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        message = f"cout: {error}"
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            message = f"cout: {error.stderr.strip()}"
        if args.notify:
            tmux("display-message", "-l", "-t", args.pane, message)
        else:
            print(message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

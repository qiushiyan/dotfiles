#!/usr/bin/env python3
"""Exercise the cout binary with real Zsh in Rex blocks on a private Rex server.

The Rex counterpart of test-cout.py: the binary under test is $COUT_BIN, else
the installed `cout` on PATH. Each case starts its own Rex server under a
short temporary HOME (the server's socket lives there and must fit a Unix
socket path), so nothing reaches the live server; every rex call runs with
REX_SERVER, REX_SESSION and REX_BLOCK removed, which would otherwise outrank
HOME from inside a Rex pane (docs/rex.md, § Where Rex's truth lives).
"""

import json
import os
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
COUT = os.environ.get("COUT_BIN") or shutil.which("cout")
REX = shutil.which("rex")
MODULE = ROOT / "zsh/.config/zsh/cout.zsh"


@unittest.skipUnless(COUT and Path(COUT).is_file(), "cout binary not found; set COUT_BIN or install it")
@unittest.skipUnless(REX, "rex not on PATH")
class CoutRexTest(unittest.TestCase):
    def setUp(self):
        # Short, for the server socket under Library/Application Support/rex.
        self.home = Path(tempfile.mkdtemp(prefix="cr.", dir="/tmp")).resolve()
        self.addCleanup(shutil.rmtree, self.home, True)
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(self.home)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("REX_", "TMUX")) and k not in ("ZDOTDIR", "HISTFILE", "TERM_PROGRAM")}
        self.env = dict(env, HOME=str(self.home), ZDOTDIR=str(self.home),
                        XDG_CACHE_HOME=str(self.home / "cache"),
                        XDG_CONFIG_HOME=str(self.home / ".config"))
        (self.home / ".config/rex").mkdir(parents=True)
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        clipboard = bin_dir / "pbcopy"
        clipboard.write_text('#!/bin/sh\ncat > "$HOME/clipboard"\n')
        clipboard.chmod(0o700)
        # Records where toclip was aimed from: in Rex, the block it runs in.
        toclip = bin_dir / "toclip"
        toclip.write_text('#!/bin/sh\nprintf "%s|%s" "$REX_BLOCK" "$TMUX_PANE" > "$HOME/toclip-from"\nexec pbcopy\n')
        toclip.chmod(0o700)
        (bin_dir / "cout").symlink_to(Path(COUT).resolve())
        # Rex starts a block with the server's bare system PATH; the rc file
        # gives the shell the stubs, cout, and tmux (replay renders in it).
        tmux_dir = Path(shutil.which("tmux")).parent
        (self.home / ".zshrc").write_text(
            f'export PATH={bin_dir}:{tmux_dir}:/usr/bin:/bin:/usr/sbin:/sbin\n'
            f'HISTFILE={self.home}/.zsh_history\n'
            "PS1='%# '\n"
            f'source "{MODULE}"\n'
            '_cout_setup\n'
            '_test_tick() { print -rn -- $(( ++_test_n )) > "$HOME/generation"; }\n'
            'add-zsh-hook precmd _test_tick\n'
        )
        self.server = subprocess.Popen([REX, "--autostart=false", "server", "run"], env=self.env, cwd=self.home,
                                       stdout=subprocess.DEVNULL, stderr=open(self.home / "server.log", "w"))
        self.addCleanup(self.stop_server)
        self.wait(lambda: self.rex_ok("server", "status"), "server did not start")
        created = json.loads(self.rex("new", "t", "--json", "--shell", "none", "-c", str(self.home),
                                      "--", "/bin/zsh", "-i"))
        self.session = created["session_id"]
        self.block = created["initial_windows"][0]["block_ids"][0]
        self.wait(lambda: self.generation() == "1", "shell did not reach its first prompt")
        time.sleep(.1)

    def stop_server(self):
        self.rex_ok("server", "stop")
        try:
            self.server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.server.kill()
            self.server.wait()

    def tearDown(self):
        # The recorder deletes its store when its block closes.
        stores = list((self.home / "cache/cout").glob("pane-*")) if (self.home / "cache/cout").exists() else []
        self.rex_ok("block", "close", self.block)
        deadline = time.monotonic() + 5
        while any(s.exists() for s in stores) and time.monotonic() < deadline:
            time.sleep(.03)
        self.assertFalse(any(s.exists() for s in stores), "block recorder must clean up after its block closes")

    def rex(self, *args):
        return subprocess.check_output([REX, "--autostart=false", *args], env=self.env, text=True,
                                       stderr=subprocess.PIPE)

    def rex_ok(self, *args):
        return subprocess.run([REX, "--autostart=false", *args], env=self.env,
                              capture_output=True).returncode == 0

    def generation(self):
        try:
            return (self.home / "generation").read_text()
        except FileNotFoundError:
            return ""

    def wait(self, predicate, message="shell did not reach the expected state"):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.03)
        self.fail(message + ":\n" + self.screen())

    def screen(self):
        try:
            return self.rex("capture", "-b", self.block, "--unwrap", "--trim")
        except subprocess.CalledProcessError as e:
            return f"(no screen: {e.stderr})"

    def send(self, data):
        self.rex("send", "-b", self.block, data)

    def execute(self, command):
        generation = self.generation()
        self.send("\x1b[200~" + command + "\x1b[201~")
        self.send("\r")
        self.wait(lambda: self.generation() != generation)
        time.sleep(.1)

    def store(self):
        """The block's store, refused unless it lies inside this test's cache."""
        cache = (self.home / "cache/cout").resolve()
        for manifest in cache.glob("pane-*/recorder.json"):
            if json.loads(manifest.read_text()).get("block") == self.block:
                store = manifest.parent.resolve()
                if cache in store.parents:
                    return store
        self.fail(f"no store for {self.block} inside {cache}")

    def state(self):
        return (self.store() / "state").read_text().split()

    def fenced(self, transcript, cwd=None):
        return f"\n```\n# run from {cwd or self.home}\n{transcript}```\n"

    def capture(self, success=True, index=1, env=None):
        result = subprocess.run([COUT, "--pane", self.block, "--print", str(index)],
                                env=env or self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr + result.stdout)
        return result.stdout if success else result.stderr

    def test_streams_exact_command_and_copies_from_the_block(self):
        cmd = "printf '\\033[31mhello\\033[0m\\n'; printf 'error\\n' >&2; false"
        self.execute(cmd)
        expected = self.fenced("$ " + cmd + "\nhello\nerror\n")
        self.assertEqual(self.capture(), expected)
        # cout in the block's own shell finds the block without --pane.
        self.execute("cout")
        self.assertEqual((self.home / "clipboard").read_text(), expected)
        self.assertEqual((self.home / "toclip-from").read_text(), self.block + "|")
        self.assertIn('Copied "printf', self.screen())
        self.assertEqual(self.capture(), expected)

    def test_indexed_history_skips_copies_and_empty_prompts(self):
        self.execute("print first")
        self.execute("cout")
        self.execute("")
        self.execute("true")
        self.assertEqual(self.capture(index=2), self.fenced("$ print first\nfirst\n"))
        self.assertEqual(self.capture(), self.fenced("$ true\n"))
        self.assertIn("unavailable", self.capture(success=False, index=3))

    def test_directory_wrapped_and_unterminated_output(self):
        (self.home / "sub dir").mkdir()
        self.execute("cd 'sub dir'")
        cmd = "printf '%s\\n' '" + "long 界 " * 30 + "'"
        self.execute(cmd)
        self.assertEqual(self.capture(), self.fenced("$ " + cmd + "\n" + "long 界 " * 30 + "\n",
                                                     cwd=self.home / "sub dir"))
        self.execute("printf no-newline")
        lines = [line.rstrip() for line in self.capture().splitlines()]
        self.assertEqual(lines[-2:], ["no-newline%", "```"])

    def test_resize_during_and_after_a_command_leaves_no_rex_frames(self):
        self.execute("print before; sleep 0.6; print after")
        cmd = "print before; sleep 1; print after"
        generation = self.generation()
        self.send("\x1b[200~" + cmd + "\x1b[201~\r")
        time.sleep(.3)
        self.rex("block", "call", "resize", '{"columns":50,"rows":20}', "-b", self.block)
        self.wait(lambda: self.generation() != generation)
        time.sleep(.1)
        self.assertEqual(self.capture(), self.fenced("$ " + cmd + "\nbefore\nafter\n"))
        identity = self.state()[2]
        raw = (self.store() / f"{identity}.raw").read_bytes()
        self.assertNotIn(b"\x1b_rex1", raw)
        # A completed record ignores later resizes and a cleared screen.
        self.rex("block", "call", "resize", '{"columns":30,"rows":12}', "-b", self.block)
        self.rex("block", "call", "clear", "-b", self.block)
        self.assertEqual(self.capture(), self.fenced("$ " + cmd + "\nbefore\nafter\n"))

    def test_large_output_arrives_whole(self):
        cmd = "seq 1 40000"
        self.execute(cmd)
        self.assertEqual(self.capture(), self.fenced("$ " + cmd + "\n" + "".join(f"{i}\n" for i in range(1, 40001))))

    def test_nested_shell_and_exec_keep_one_recorder(self):
        self.execute("print parent")
        store = self.store()
        self.execute("zsh")
        self.execute("print child")
        self.assertEqual(self.capture(), self.fenced("$ print child\nchild\n"))
        self.execute("exit")
        self.assertEqual(self.capture(index=2), self.fenced("$ print parent\nparent\n"))
        self.execute("exec zsh")
        self.execute("print new")
        self.assertEqual(self.store(), store)
        self.assertEqual(self.capture(), self.fenced("$ print new\nnew\n"))

    def test_running_command_is_refused(self):
        self.execute("print hello")
        self.send("sleep 30\r")
        self.wait(lambda: self.state()[0] == "0")
        self.assertIn("no completed command", self.capture(success=False))
        self.send("\x03")
        self.wait(lambda: self.state()[0] == "1")
        self.assertEqual(self.capture(index=2), self.fenced("$ print hello\nhello\n"))

    def test_killed_recorder_reports_and_reload_reaps(self):
        self.execute("print retained")
        store = self.store()
        pid = json.loads((store / "recorder.json").read_text())["pid"]
        os.kill(pid, signal.SIGKILL)
        started = time.monotonic()
        self.assertIn("recorder stopped; run zshreload", self.capture(success=False))
        self.assertLess(time.monotonic() - started, 2)
        self.execute("exec zsh")
        self.execute("print recovered")
        self.assertEqual(self.capture(), self.fenced("$ print recovered\nrecovered\n"))
        self.assertFalse(store.exists())

    def test_recorder_takes_no_size_and_names_itself(self):
        self.execute("true")
        size = json.loads(self.rex("block", "call", "size", "-b", self.block))
        self.assertIsNone(size["owner"])
        clients = json.loads(self.rex("api", "call", "client.list", '{"kinds":["other"]}'))["clients"]
        self.assertEqual([c["info"].get("name") for c in clients], ["cout"])

    def test_outside_any_pane_is_a_usage_error(self):
        env = {k: v for k, v in self.env.items() if k not in ("TERM_PROGRAM",)}
        result = subprocess.run([COUT, "--print"], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        result = subprocess.run([COUT, "--pane", self.block, "--notify"], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Exercise cout with real Zsh/Oh My Posh on a private tmux socket."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[5]
HELPER = ROOT / "tmux/.config/tmux/scripts/tmux-cout.py"
MODULE = ROOT / "zsh/.config/zsh/cout.zsh"
PROMPT = ROOT / "ohmyposh/.config/ohmyposh/zen.omp.json"


class CoutTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cout-test-")
        self.home = Path(self.temp.name)
        self.socket = str(self.home / "tmux.sock")
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        XDG_CACHE_HOME=str(self.home / "cache"),
                        XDG_CONFIG_HOME=str(self.home / ".config"))
        self.env.pop("TMUX", None)
        self.env.pop("TMUX_PANE", None)
        self.env.pop("POSH_SESSION_ID", None)
        (self.home / "bin").mkdir()
        clipboard = self.home / "bin/pbcopy"
        clipboard.write_text('#!/bin/sh\ncat > "$HOME/clipboard"\n')
        clipboard.chmod(0o700)
        self.env["PATH"] = str(self.home / "bin") + ":" + self.env["PATH"]
        helper = self.home / ".config/tmux/scripts/tmux-cout.py"
        helper.parent.mkdir(parents=True)
        shutil.copyfile(HELPER, helper)
        (self.home / ".zshrc").write_text(
            f'source "{MODULE}"\n'
            f'eval "$(oh-my-posh init zsh --config {PROMPT})"\n'
            '_cout_setup\n'
            '_test_tick() { (( ++_test_generation )); '
            'tmux set-option -p -t "$TMUX_PANE" @test-generation "$_test_generation"; }\n'
            'add-zsh-hook precmd _test_tick\n'
        )
        self.tmux("-f", "/dev/null", "new-session", "-d", "-x", "60", "-y", "16",
                  "-c", str(self.home), "/bin/zsh")
        self.env["TMUX"] = self.socket + ",0,0"
        self.pane = self.tmux("display-message", "-p", "#{pane_id}").strip()
        self.wait(lambda: self.option("@test-generation") == "1")
        time.sleep(.1)

    def tearDown(self):
        self.tmux("kill-server")
        self.temp.cleanup()

    def tmux(self, *args):
        return subprocess.check_output(["tmux", "-S", self.socket, *args],
                                       env=self.env, text=True)

    def option(self, name):
        return self.tmux("show-options", "-pqv", "-t", self.pane, name).strip()

    def wait(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.03)
        self.fail("shell did not reach the expected state:\n" +
                  self.tmux("capture-pane", "-p", "-F", "-t", self.pane))

    def execute(self, command):
        generation = self.option("@test-generation")
        self.tmux("send-keys", "-t", self.pane, "-l", "\x1b[200~" + command + "\x1b[201~")
        self.tmux("send-keys", "-t", self.pane, "Enter")
        self.wait(lambda: self.option("@test-generation") != generation)
        # precmd finishes immediately before Zsh actually paints PS1.
        time.sleep(.1)

    def capture(self, success=True):
        result = subprocess.run(["python3", str(HELPER), "--pane", self.pane, "--print"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr + result.stdout)
        return result.stdout if success else result.stderr

    def test_streams_exact_command_and_repeated_copy(self):
        cmd = "printf '\\033[31mhello\\033[0m\\n'; printf 'error\\n' >&2; false"
        self.execute(cmd)
        expected = "$ " + cmd + "\nhello\nerror\n"
        self.assertEqual(self.capture(), expected)
        for _ in range(2):
            self.execute("cout")
            self.assertEqual((self.home / "clipboard").read_text(), expected)
            self.assertEqual(self.capture(), expected)
        self.execute("")
        self.assertEqual(self.capture(), expected)

    def test_silent_and_multiline_wrapped_output(self):
        self.execute("true")
        self.assertEqual(self.capture(), "$ true\n")
        cmd = "printf '%s\\n' \\\n  '" + "long 界 " * 30 + "'"
        self.execute(cmd)
        self.assertEqual(self.capture(), "$ " + cmd + "\n" + "long 界 " * 30 + "\n")

    def test_shortcut_cancelled_prompt_and_no_final_newline(self):
        self.execute("printf no-newline")
        expected = self.capture()
        # Zsh pads its visible missing-newline marker to the right margin.
        self.assertEqual([line.rstrip() for line in expected.splitlines()],
                         ["$ printf no-newline", "no-newline%"])
        generation = self.option("@test-generation")
        self.tmux("send-keys", "-t", self.pane, "-l", "not executed")
        self.tmux("send-keys", "-t", self.pane, "C-c")
        self.wait(lambda: self.option("@test-generation") != generation)
        time.sleep(.1)
        self.assertEqual(self.capture(), expected)
        binding = next(line for line in (ROOT / "tmux/.config/tmux/tmux.conf").read_text().splitlines()
                       if line.startswith("bind-key o "))
        binding_file = self.home / "binding.conf"
        binding_file.write_text(binding + "\n")
        self.tmux("source-file", str(binding_file))
        installed = self.tmux("list-keys", "-T", "prefix")
        self.assertIn("tmux-cout.py", installed)
        # Run the exact bound action; no attached client is needed by the suite.
        action = shlex.split(binding)[2:]
        action[-1] = action[-1].replace("#{pane_id}", self.pane)
        self.tmux(*action)
        self.wait(lambda: (self.home / "clipboard").exists())
        self.assertEqual((self.home / "clipboard").read_text(), expected)

    def test_scrollback_and_pane_target(self):
        cmd = "for i in {1..80}; do print row-$i; done"
        self.execute(cmd)
        expected = "$ " + cmd + "\n" + "".join(f"row-{i}\n" for i in range(1, 81))
        self.assertEqual(self.capture(), expected)
        # A different active pane must never change the source of the copy.
        self.tmux("split-window", "-h", "-t", self.pane, "/bin/sleep 30")
        self.assertEqual(self.capture(), expected)

    def test_missing_boundaries_and_running_command_leave_clipboard_alone(self):
        sentinel = self.home / "clipboard"
        sentinel.write_text("keep me")
        self.assertIn("no completed command", self.capture(success=False))
        self.execute("print hello")
        self.tmux("send-keys", "-t", self.pane, "-l", "sleep 30")
        self.tmux("send-keys", "-t", self.pane, "Enter")
        self.wait(lambda: self.option("@cout-ready") == "0")
        self.capture(success=False)
        self.tmux("send-keys", "-t", self.pane, "C-c")
        self.wait(lambda: self.option("@cout-ready") == "1")
        self.execute("for i in {1..80}; do print row-$i; done")
        self.tmux("clear-history", "-t", self.pane)
        result = subprocess.run(["python3", str(HELPER), "--pane", self.pane],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("boundaries", result.stderr)
        self.assertEqual(sentinel.read_text(), "keep me")


if __name__ == "__main__":
    unittest.main(verbosity=2)

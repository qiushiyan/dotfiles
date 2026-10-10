#!/usr/bin/env python3
"""Exercise the cout binary with real Zsh/Oh My Posh on a private tmux socket.

The binary under test is $COUT_BIN, else the installed `cout` on PATH
(~/dev/cout; `make install`). Its unit tests live in that repository.
"""

import os
import json
import signal
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[5]
COUT = os.environ.get("COUT_BIN") or shutil.which("cout")
TMUX = shutil.which("tmux")
MODULE = ROOT / "zsh/.config/zsh/cout.zsh"
PROMPT = ROOT / "ohmyposh/.config/ohmyposh/zen.omp.json"


@unittest.skipUnless(COUT and Path(COUT).is_file(), "cout binary not found; set COUT_BIN or install it")
class CoutTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cout-test-")
        self.home = Path(self.temp.name)
        # Work from the sandbox, so a relative path can never name the checkout.
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(self.home)
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
        # cout copies through toclip when it is on PATH; this stub shadows
        # the installed one, records the pane it was aimed from, then copies.
        toclip = self.home / "bin/toclip"
        toclip.write_text('#!/bin/sh\nprintf %s "$TMUX_PANE" > "$HOME/toclip-pane"\nexec pbcopy\n')
        toclip.chmod(0o700)
        # The pane's shell and the tmux binding find the binary under test first.
        (self.home / "bin/cout").symlink_to(Path(COUT).resolve())
        self.env["PATH"] = str(self.home / "bin") + ":" + self.env["PATH"]
        (self.home / ".zshrc").write_text(
            f'source "{MODULE}"\n'
            f'eval "$(oh-my-posh init zsh --config {PROMPT})"\n'
            '_cout_setup\n'
            '_test_tick() { local n=$(tmux show-options -pqv -t "$TMUX_PANE" @test-generation); '
            'tmux set-option -p -t "$TMUX_PANE" @test-generation "$(( ${n:-0} + 1 ))"; }\n'
            'add-zsh-hook precmd _test_tick\n'
        )
        self.tmux("-f", "/dev/null", "new-session", "-d", "-x", "60", "-y", "16",
                  "-c", str(self.home), "/bin/zsh")
        self.env["TMUX"] = self.socket + ",0,0"
        self.pane = self.tmux("display-message", "-p", "#{pane_id}").strip()
        self.wait(lambda: self.option("@test-generation") == "1")
        time.sleep(.1)

    def tearDown(self):
        store_name = self.option("@cout-store")
        store = Path(store_name) if store_name else None
        self.tmux("kill-server")
        deadline = time.monotonic() + 5
        while store and store.exists() and time.monotonic() < deadline:
            time.sleep(.03)
        self.assertFalse(store and store.exists(), "pane recorder must clean up after server exit")
        self.temp.cleanup()

    def tmux(self, *args):
        return subprocess.check_output(["tmux", "-S", self.socket, *args],
                                       env=self.env, text=True)

    def store(self):
        """The pane's store, refused unless it lies inside this test's cache.

        An unset option is Path("") == Path("."), the working directory: a
        delete through it once emptied the dotfiles checkout.
        """
        name = self.option("@cout-store")
        cache = (self.home / "cache").resolve()
        store = Path(name)
        if not name or not store.is_absolute() or cache not in store.resolve().parents:
            self.fail(f"@cout-store {name!r} is not a store inside {cache}")
        return store

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

    def fenced(self, transcript, cwd=None):
        """The text cout delivers: a Markdown code block that opens on the
        directory the command ran from, the pane's starting one by default."""
        return f"\n```\n# run from {cwd or self.home}\n{transcript}```\n"

    def capture(self, success=True, index=1):
        result = subprocess.run([COUT, "--pane", self.pane, "--print", str(index)],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr + result.stdout)
        return result.stdout if success else result.stderr

    def test_streams_exact_command_and_repeated_copy(self):
        cmd = "printf '\\033[31mhello\\033[0m\\n'; printf 'error\\n' >&2; false"
        self.execute(cmd)
        expected = self.fenced("$ " + cmd + "\nhello\nerror\n")
        self.assertEqual(self.capture(), expected)
        for _ in range(2):
            self.execute("cout")
            self.assertEqual((self.home / "clipboard").read_text(), expected)
            self.assertEqual(self.capture(), expected)
        self.execute("")
        self.assertEqual(self.capture(), expected)

    def test_indexed_history_skips_copies_and_empty_prompts(self):
        first = "printf '%s\\n' \\\n  'first command with a long enough title to truncate the notification'"
        self.execute(first)
        first_text = self.capture()
        self.execute("cout 1")
        self.assertEqual((self.home / "clipboard").read_text(), first_text)
        self.execute("")
        self.execute("true")
        self.execute("cout 2")
        self.assertEqual((self.home / "clipboard").read_text(), first_text)
        self.assertEqual(self.capture(index=2), first_text)
        self.assertEqual(self.capture(), self.fenced("$ true\n"))
        self.execute("print third")
        third_text = self.fenced("$ print third\nthird\n")
        for invocation, expected in [("cout 3", first_text), ("cout 2", self.fenced("$ true\n")),
                                     ("cout", third_text), ("cout 1", third_text)]:
            self.execute(invocation)
            self.assertEqual((self.home / "clipboard").read_text(), expected)
        screen = self.tmux("capture-pane", "-p", "-J", "-S", "-", "-t", self.pane)
        self.assertIn('Copied "print third"', screen)
        self.assertIn('Copied "true"', screen)
        preview = " ".join(first.split())[:40] + "…"
        self.assertIn(f'Copied "{preview}"', screen)
        self.assertNotIn("Copied", self.capture(index=3))

    def test_invalid_indices_and_clipboard_failure_preserve_history(self):
        self.execute("print original")
        expected = self.capture()
        self.execute("cout")
        (self.home / "clipboard").write_text("untouched")
        for invocation in ["cout 0", "cout -1", "cout abc", "cout 1.5", "cout 1 2",
                           "cout ''", "cout 2", "cout 9999999999999999999999999"]:
            self.execute(invocation)
            self.assertEqual((self.home / "clipboard").read_text(), "untouched", invocation)
            self.assertEqual(self.capture(), expected)
        self.assertIn("unavailable", self.capture(success=False, index=2))
        clipboard = self.home / "bin/pbcopy"
        clipboard.write_text("#!/bin/sh\nexit 1\n")
        before = self.tmux("capture-pane", "-p", "-S", "-", "-t", self.pane).count('Copied "print original"')
        self.assertEqual(before, 1)
        self.execute("cout")
        after = self.tmux("capture-pane", "-p", "-S", "-", "-t", self.pane).count('Copied "print original"')
        self.assertEqual(before, after)
        self.assertEqual(self.capture(), expected)

    def test_silent_and_multiline_wrapped_output(self):
        self.execute("true")
        self.assertEqual(self.capture(), self.fenced("$ true\n"))
        cmd = "printf '%s\\n' \\\n  '" + "long 界 " * 30 + "'"
        self.execute(cmd)
        self.assertEqual(self.capture(), self.fenced("$ " + cmd + "\n" + "long 界 " * 30 + "\n"))

    def test_block_names_the_directory_each_command_ran_from(self):
        elsewhere = self.home / "sub dir"
        elsewhere.mkdir()
        self.execute("print before")
        self.execute("cd 'sub dir'")
        self.execute("print after")
        self.assertEqual(self.capture(), self.fenced("$ print after\nafter\n", cwd=elsewhere))
        # cd ran from the directory it left, and leaves earlier records alone.
        self.assertEqual(self.capture(index=2), self.fenced("$ cd 'sub dir'\n"))
        self.assertEqual(self.capture(index=3), self.fenced("$ print before\nbefore\n"))
        # A shell running older hooks writes no directory; the line is left out.
        identity = self.option("@cout-state").split()[1]
        (self.store() / f"{identity}.cwd").unlink()
        self.assertEqual(self.capture(), "\n```\n$ print after\nafter\n```\n")

    def test_nested_shell_preserves_parent_and_child_records(self):
        self.execute("print parent_a")
        self.execute("print parent_b")
        self.execute("zsh")
        self.execute("print child")
        self.assertEqual(self.capture(), self.fenced("$ print child\nchild\n"))
        self.execute("exit")
        store = self.store()
        exited = next(p for p in store.glob("*.command") if p.read_text() == "exit")
        self.wait(lambda: exited.with_suffix(".json").exists())
        self.assertEqual(self.capture(index=2), self.fenced("$ print parent_b\nparent_b\n"))
        self.assertEqual(self.capture(index=3), self.fenced("$ print parent_a\nparent_a\n"))
        self.assertTrue(self.capture().startswith(f"\n```\n# run from {self.home}\n$ zsh\n"))
        self.assertIn("child", self.capture())

    def test_completed_record_survives_resize_and_clear_history(self):
        command = "printf '%s\\n' '" + "wide 界 " * 40 + "'"
        self.execute(command)
        expected = self.fenced("$ " + command + "\n" + "wide 界 " * 40 + "\n")
        self.tmux("resize-window", "-t", self.pane, "-x", "30", "-y", "16")
        self.tmux("clear-history", "-t", self.pane)
        self.assertEqual(self.capture(), expected)

    def test_foreign_prompt_markers_progress_and_blank_lines(self):
        command = "printf '\\033]133;A\\aREMOTE> \\033]133;B\\a\\r\\033[2Kprogress 1\\rprogress 2\\n\\n   \\n'"
        self.execute(command)
        self.assertEqual(self.capture(), self.fenced("$ " + command + "\nprogress 2\n\n   \n"))
        self.execute("print next")
        self.assertEqual(self.capture(index=2), self.fenced("$ " + command + "\nprogress 2\n\n   \n"))

    def test_exec_reload_and_foreign_pipe_are_isolated(self):
        self.execute("print old")
        old_store = str(self.store())
        before = set(Path(old_store).glob("*.command"))
        self.execute("exec zsh")
        self.assertEqual(self.option("@cout-store"), old_store)
        self.assertIn("no completed command", self.capture(success=False))
        self.execute("print new")
        self.assertEqual(self.capture(), self.fenced("$ print new\nnew\n"))
        replaced = next(p for p in set(Path(old_store).glob("*.command")) - before
                        if p.read_text() == "exec zsh")
        metadata = json.loads(replaced.with_suffix(".json").read_text())
        self.assertIn("replaced", metadata["error"])
        size = replaced.with_suffix(".raw").stat().st_size

        self.assertIn("unavailable", self.capture(success=False, index=2))
        self.execute("print more output")
        self.assertEqual(replaced.with_suffix(".raw").stat().st_size, size)
        # Another logger takes over the pipe; setup must leave it running.
        self.tmux("pipe-pane", "-O", "-t", self.pane, "cat > " + shlex.quote(str(self.home / "foreign")))
        self.wait(lambda: not Path(old_store).exists())
        result = subprocess.run([COUT, "setup", "--pane", self.pane],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already has an output pipe", result.stderr)
        self.tmux("send-keys", "-t", self.pane, "-l", "logger still alive")
        self.wait(lambda: "logger still alive" in (self.home / "foreign").read_text())

    def test_removed_cache_reports_once_and_reload_recovers(self):
        self.execute("print retained")
        store = self.store()
        shutil.rmtree(store)
        self.execute("print one")
        self.execute("print two")
        screen = self.tmux("capture-pane", "-p", "-J", "-S", "-", "-t", self.pane)
        self.assertNotIn("_cout_preexec:", screen)
        self.assertEqual(screen.count("cout: recording stopped; run zshreload to restart it."), 1)
        self.execute("exec zsh")
        self.execute("print recovered")
        self.assertEqual(self.capture(), self.fenced("$ print recovered\nrecovered\n"))

    def test_killed_recorder_reports_promptly_and_reload_reaps_cache(self):
        self.execute("print retained")
        store = self.store()
        pid = json.loads((store / "recorder.json").read_text())["pid"]
        os.kill(pid, signal.SIGKILL)
        self.execute("print one")
        self.wait(lambda: self.tmux("display-message", "-p", "-t", self.pane, "#{pane_pipe}").strip() == "0")
        started = time.monotonic()
        self.assertIn("recorder stopped; run zshreload", self.capture(success=False))
        self.assertLess(time.monotonic() - started, 2, "dead recorder must not wait for completion timeout")
        self.execute("print two")
        self.assertNotIn("_cout_preexec:", self.tmux("capture-pane", "-p", "-J", "-t", self.pane))
        self.execute("exec zsh")
        self.execute("print recovered")
        self.assertEqual(self.capture(), self.fenced("$ print recovered\nrecovered\n"))
        self.assertFalse(store.exists())

    def test_recorder_fault_keeps_completed_records_until_recovery(self):
        self.execute("print retained")
        store = self.store()
        identity = self.option("@cout-state").split()[1]
        saved = (store / f"{identity}.raw").read_bytes()
        self.execute("_cout_mark invalid")
        self.wait(lambda: self.tmux("display-message", "-p", "-t", self.pane, "#{pane_pipe}").strip() == "0")
        self.assertEqual((store / f"{identity}.raw").read_bytes(), saved)
        # The recorder kept why it stopped, and the copy says so.
        self.assertIn('recorder stopped: invalid recorder marker "invalid"; run zshreload',
                      self.capture(success=False))
        self.execute("exec zsh")
        self.execute("print recovered")
        self.assertEqual(self.capture(), self.fenced("$ print recovered\nrecovered\n"))
        self.assertFalse(store.exists())

    def test_selected_copy_survives_starting_another_command(self):
        self.execute("print selected")
        # Hold the copy after it selected its record, at the start of its
        # private render server; every other tmux call passes straight through.
        wrapper = self.home / "hold/tmux"
        wrapper.parent.mkdir()
        wrapper.write_text(
            '#!/bin/sh\n'
            'case "$*" in *cout-render-*new-session*)\n'
            '  touch "$HOLD/render-started"\n'
            '  while [ ! -e "$HOLD/render-release" ]; do sleep 0.01; done ;;\n'
            f'esac\nexec {shlex.quote(TMUX)} "$@"\n')
        wrapper.chmod(0o700)
        env = dict(self.env, HOLD=str(self.home), PATH=f"{wrapper.parent}:{self.env['PATH']}")
        process = subprocess.Popen([COUT, "--pane", self.pane],
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.wait(lambda: (self.home / "render-started").exists())
            self.execute("print next")
        finally:
            (self.home / "render-release").touch()
            stdout, stderr = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual((self.home / "clipboard").read_text(), self.fenced("$ print selected\nselected\n"))
        self.assertIn('Copied "print selected"', stdout)

    def test_recording_limits_prune_and_refuse_truncated_output(self):
        self.execute("true")
        # Limits belong to the recorder, so they apply to the next one setup
        # attaches: from a shell that exports them, after this pipe closes.
        self.execute("export COUT_LIMITS=1024,2048,3")
        store = self.store()
        self.tmux("pipe-pane", "-t", self.pane)
        self.wait(lambda: not store.exists())
        self.execute("exec zsh")
        for letter in "abc":
            self.execute("print '" + letter * 900 + "'")
        self.assertIn("b" * 900, self.capture(index=2))
        self.assertIn("unavailable", self.capture(success=False, index=3))
        for number in range(4):
            self.execute(f"print short-{number}")
        self.assertIn("short-1", self.capture(index=3))
        self.assertIn("unavailable", self.capture(success=False, index=4))
        store = self.store()
        self.assertEqual(len(list(store.glob("*.command"))), 3)
        self.assertEqual(len(list(store.glob("*.cwd"))), 3)
        self.assertLessEqual(sum(p.stat().st_size for p in store.glob("*.raw")), 2048)
        self.assertEqual(store.stat().st_mode & 0o777, 0o700)
        self.assertTrue(all(p.stat().st_mode & 0o777 == 0o600 for p in store.iterdir()))
        (self.home / "clipboard").write_text("untouched")
        self.execute("print '" + "x" * 1500 + "'")
        self.execute("cout")
        self.assertIn("per-command recording limit", self.capture(success=False))
        self.assertEqual((self.home / "clipboard").read_text(), "untouched")

    def test_full_screen_output_does_not_change_clipboard(self):
        (self.home / "clipboard").write_text("untouched")
        for mode in ("1049", "25;1049", "1049;25"):
            self.execute(f"printf '\\033[?{mode}hhidden\\033[?1049l'")
            self.execute("cout")
            self.assertEqual((self.home / "clipboard").read_text(), "untouched")
            self.assertIn("full-screen", self.capture(success=False))

    def test_old_shell_metadata_requests_reload_without_copying(self):
        self.execute("print retained")
        (self.home / "clipboard").write_text("untouched")
        # An already-running shell can still be publishing the previous format.
        self.tmux("set-option", "-pu", "-t", self.pane, "@cout-state")
        result = subprocess.run([COUT, "--pane", self.pane],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("zshreload", result.stderr)
        self.assertEqual((self.home / "clipboard").read_text(), "untouched")

    def test_shortcut_cancelled_prompt_and_no_final_newline(self):
        self.execute("printf no-newline")
        expected = self.capture()
        # Zsh pads its visible missing-newline marker to the right margin.
        self.assertEqual([line.rstrip() for line in expected.splitlines()],
                         ["", "```", f"# run from {self.home}", "$ printf no-newline", "no-newline%", "```"])
        generation = self.option("@test-generation")
        self.tmux("send-keys", "-t", self.pane, "-l", "not executed")
        self.tmux("send-keys", "-t", self.pane, "C-c")
        self.wait(lambda: self.option("@test-generation") != generation)
        time.sleep(.1)
        self.assertEqual(self.capture(), expected)
        binding = self.bind_shortcut()
        installed = self.tmux("list-keys", "-T", "prefix")
        self.assertIn("cout --pane", installed)
        self.assertNotIn("python", binding)
        self.press_shortcut(binding)
        self.wait(lambda: (self.home / "clipboard").exists())
        self.assertEqual((self.home / "clipboard").read_text(), expected)
        # run-shell has no TMUX_PANE; toclip must still aim from the bound pane.
        self.assertEqual((self.home / "toclip-pane").read_text(), self.pane)

    def bind_shortcut(self):
        binding = next(line for line in (ROOT / "tmux/.config/tmux/tmux.conf").read_text().splitlines()
                       if line.startswith("bind-key o "))
        binding_file = self.home / "binding.conf"
        binding_file.write_text(binding + "\n")
        self.tmux("source-file", str(binding_file))
        return binding

    def press_shortcut(self, binding):
        # Run the exact bound action; no attached client is needed by the suite.
        action = shlex.split(binding)[2:]
        action[-1] = action[-1].replace("#{pane_id}", self.pane)
        self.tmux(*action)

    def test_shortcut_failure_leaves_no_popup(self):
        # run-shell shows a non-zero exit or any output in a view-mode popup;
        # --notify reports in the status line and exits 0 instead.
        (self.home / "clipboard").write_text("untouched")
        status = self.home / "cout-status"
        wrapper = self.home / "bin/cout"
        wrapper.unlink()
        wrapper.write_text(f'#!/bin/sh\n{shlex.quote(str(Path(COUT).resolve()))} "$@"\n'
                           f'code=$?\necho $code > {shlex.quote(str(status))}\nexit $code\n')
        wrapper.chmod(0o700)
        self.press_shortcut(self.bind_shortcut())
        self.wait(lambda: status.exists())
        time.sleep(.2)  # run-shell reacts to the job's exit after it happens
        self.assertEqual(status.read_text().strip(), "0")
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane, "#{pane_in_mode}").strip(), "0")
        self.assertEqual((self.home / "clipboard").read_text(), "untouched")

    def test_toclip_refusal_reaches_the_user(self):
        self.execute("print hello")
        (self.home / "bin/toclip").write_text(
            "#!/bin/sh\necho 'toclip: too large; kept as the newest tmux buffer - run frommini' >&2\nexit 1\n")
        result = subprocess.run([COUT, "--pane", self.pane],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("run frommini", result.stderr)

    def test_scrollback_and_pane_target(self):
        cmd = "for i in {1..80}; do print row-$i; done"
        self.execute(cmd)
        expected = self.fenced("$ " + cmd + "\n" + "".join(f"row-{i}\n" for i in range(1, 81)))
        self.assertEqual(self.capture(), expected)
        # A different active pane must never change the source of the copy.
        self.tmux("split-window", "-h", "-t", self.pane, "/bin/sleep 30")
        self.assertEqual(self.capture(), expected)

    def test_missing_record_and_running_command_leave_clipboard_alone(self):
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
        store = self.store()
        identity = self.option("@cout-state").split()[1]
        (store / f"{identity}.raw").unlink()
        result = subprocess.run([COUT, "--pane", self.pane],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("recording is no longer retained", result.stderr)
        self.assertEqual(sentinel.read_text(), "keep me")


if __name__ == "__main__":
    unittest.main(verbosity=2)

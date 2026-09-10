"""Safety checks against disposable repositories; never use the user's Git config.

Run: python3 -m unittest discover -s tests -v
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "remove.py"


class RemoveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="clean-worktrees-test-")
        self.addCleanup(self.temporary.cleanup)
        self.sandbox = Path(self.temporary.name).resolve()
        self.root = self.sandbox / "checkouts"
        self.root.mkdir()
        self.repo = self.root / "main"
        self.backups = self.sandbox / "backups"
        self.home = self.sandbox / "home"
        self.home.mkdir()
        self.hooks = self.sandbox / "empty-hooks"
        self.hooks.mkdir()
        self.env = {
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "TMPDIR": str(self.sandbox),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TEMPLATE_DIR": str(self.hooks),
            "GIT_TERMINAL_PROMPT": "0",
        }
        self.run_command("git", "init", "-b", "main", str(self.repo))
        self.git("config", "user.name", "Synthetic Test")
        self.git("config", "user.email", "synthetic@example.invalid")
        self.git("config", "core.hooksPath", str(self.hooks))
        (self.repo / "tracked.txt").write_text("baseline\n")
        (self.repo / ".gitignore").write_text(".env\nnode_modules/\nlocal-data/\n")
        self.git("add", ".")
        self.git("commit", "-m", "Synthetic baseline")
        self.initial_head = self.git("rev-parse", "HEAD").strip()

    def run_command(self, *args, cwd=None, check=True):
        return subprocess.run(
            args, cwd=cwd or self.sandbox, env=self.env,
            text=True, capture_output=True, check=check, timeout=90,
        )

    def git(self, *args, cwd=None):
        return self.run_command("git", "-C", str(cwd or self.repo), *args).stdout

    def checkout(self, name, *, path=None, detached=False):
        path = path or self.root / name
        flags = ["--detach"] if detached else ["-b", name]
        self.git("worktree", "add", *flags, str(path), "HEAD")
        return path

    def candidate(self, path, *, head=None):
        return {"path": str(path), "head": head or self.initial_head,
                "reason": "Synthetic fixture audited for this test"}

    def invoke(self, candidates, *, apply=True, jobs=2, kept=None):
        plan = self.sandbox / "plan.json"
        plan.write_text(json.dumps({"root": str(self.root), "candidates": candidates,
                                    "kept": kept or []}))
        args = [sys.executable, str(HELPER), str(plan), "--jobs", str(jobs),
                "--backup-root", str(self.backups)]
        if apply:
            args.append("--apply")
        process = self.run_command(*args)
        output = [json.loads(line) for line in process.stdout.splitlines()]
        if not apply:
            return output
        report = Path(output[-1]["report"])
        self.assertTrue(report.is_relative_to(self.backups))
        result = json.loads(report.read_text())
        self.assertEqual(output[-1]["removed"],
                         sum(row["status"] == "removed" for row in result["results"]))
        self.assertEqual(output[-1]["skipped_or_failed"],
                         sum(row["status"] != "removed" for row in result["results"]))
        self.assertEqual(len(result["results"]), len(candidates))
        records = [json.loads(path.read_text()) for path in report.parent.glob("*.json")
                   if path.name not in {"plan.json", "results.json"}]
        self.assertCountEqual(records, result["results"])
        self.assertEqual(result["kept"], kept or [])
        return result["results"]

    def assert_removed(self, path, result):
        self.assertEqual(result["status"], "removed", result)
        self.assertFalse(path.exists())
        self.assertNotIn(str(path), self.git("worktree", "list", "--porcelain"))
        self.assertEqual(self.git("rev-parse", result["recovery_ref"]).strip(), result["head"])
        self.assertTrue(Path(result["archive"]).is_file())
        self.assertEqual(self.git("rev-parse", "main").strip(), self.initial_head)
        self.assertEqual((self.repo / "tracked.txt").read_text(), "baseline\n")

    def test_sandbox_guard_and_preview_have_no_cleanup_side_effects(self):
        self.assertEqual(self.git("config", "--global", "--list"), "")
        self.assertEqual(self.git("config", "core.hooksPath").strip(), str(self.hooks))
        path = self.checkout("preview")
        refs = self.git("show-ref")
        result = self.invoke([self.candidate(path)], apply=False)
        self.assertEqual(result[0]["status"], "ready", result)
        self.assertTrue(path.is_dir())
        self.assertFalse(self.backups.exists())
        self.assertEqual(self.git("show-ref"), refs)

    def test_merged_checkout_removed_without_deleting_branches(self):
        path = self.checkout("merged")
        result, = self.invoke([self.candidate(path)])
        self.assert_removed(path, result)
        self.assertEqual(self.git("rev-parse", "merged").strip(), self.initial_head)

    def test_dirty_untracked_locked_and_changed_head_are_kept_in_mixed_batch(self):
        dirty = self.checkout("dirty")
        (dirty / "tracked.txt").write_text("uncommitted work\n")
        untracked = self.checkout("untracked")
        (untracked / "notes.txt").write_text("unsaved notes\n")
        locked = self.checkout("locked")
        self.git("worktree", "lock", "--reason", "test protection", str(locked))
        changed = self.checkout("changed")
        (changed / "tracked.txt").write_text("new commit\n")
        self.git("commit", "-am", "Changed after audit", cwd=changed)
        clean = self.checkout("clean")
        paths = [dirty, untracked, locked, changed, clean]
        results = self.invoke([self.candidate(path) for path in paths],
                              kept=[{"path": str(self.repo), "reason": "main"}])
        by_path = {row["path"]: row for row in results}
        for path, detail in [(dirty, "uncommitted"), (untracked, "untracked"),
                             (locked, "locked"), (changed, "HEAD changed")]:
            self.assertTrue(path.is_dir())
            self.assertEqual(by_path[str(path)]["status"], "skipped")
            self.assertIn(detail, by_path[str(path)]["detail"])
        self.assertEqual((dirty / "tracked.txt").read_text(), "uncommitted work\n")
        self.assertEqual((untracked / "notes.txt").read_text(), "unsaved notes\n")
        self.assert_removed(clean, by_path[str(clean)])

    def test_main_outside_root_and_symlink_candidates_are_refused(self):
        outside = self.checkout("outside", path=self.sandbox / "outside")
        target = self.checkout("target")
        alias = self.root / "alias"
        alias.symlink_to(target, target_is_directory=True)
        results = self.invoke([self.candidate(path) for path in [self.repo, outside, alias]])
        self.assertTrue(all(row["status"] == "skipped" for row in results), results)
        for path in [self.repo, outside, alias, target]:
            self.assertTrue(path.is_dir())
        self.assertTrue(alias.is_symlink())

    def test_hidden_index_changes_are_kept(self):
        for flag in ("assume-unchanged", "skip-worktree"):
            with self.subTest(flag=flag):
                path = self.checkout(flag)
                self.git("update-index", "--" + flag, "tracked.txt", cwd=path)
                (path / "tracked.txt").write_text("hidden uncommitted work\n")
                # Git's usual dirty check misses this work; cleanup must not.
                self.assertEqual(self.git("status", "--porcelain=v1", cwd=path), "")
                preview, = self.invoke([self.candidate(path)], apply=False)
                self.assertEqual(preview["status"], "skipped", preview)
                result, = self.invoke([self.candidate(path)])
                self.assertEqual(result["status"], "skipped", result)
                self.assertEqual((path / "tracked.txt").read_text(), "hidden uncommitted work\n")
                self.assertIn(str(path), self.git("worktree", "list", "--porcelain"))

    def test_cache_named_regular_files_and_symlinks_are_archived(self):
        with (self.repo / ".gitignore").open("a") as file:
            file.write(".next\n.turbo\n")
        self.git("commit", "-am", "Ignore synthetic local cache names")
        self.initial_head = self.git("rev-parse", "HEAD").strip()
        path = self.checkout("cache-names")
        (path / ".next").write_text("local data, not a directory\n")
        external = self.sandbox / "external-file"
        external.write_text("outside data\n")
        (path / ".turbo").symlink_to(external)
        (path / "local-data").mkdir()
        (path / "local-data" / "node_modules").write_text("nested regular file\n")
        (path / "local-data" / "__pycache__").symlink_to(external)
        result, = self.invoke([self.candidate(path)])
        self.assert_removed(path, result)
        self.assertEqual(external.read_text(), "outside data\n")
        with tarfile.open(result["archive"]) as archive:
            self.assertCountEqual(archive.getnames(),
                                  [".next", ".turbo", "local-data/node_modules", "local-data/__pycache__"])
            self.assertEqual(archive.extractfile(".next").read(), b"local data, not a directory\n")
            self.assertEqual(archive.extractfile("local-data/node_modules").read(), b"nested regular file\n")
            for name in (".turbo", "local-data/__pycache__"):
                self.assertTrue(archive.getmember(name).issym())
                self.assertEqual(archive.getmember(name).linkname, str(external))

    def test_ignored_secrets_are_archived_and_external_symlinks_survive(self):
        path = self.checkout("ignored")
        (path / ".env").write_text("SYNTHETIC_TOKEN=fixture-only\n")
        (path / "node_modules").mkdir()
        (path / "node_modules" / "cache").write_text("disposable\n")
        external = self.sandbox / "external"
        external.mkdir()
        (external / "keep.txt").write_text("outside data\n")
        (path / "local-data").mkdir()
        (path / "local-data" / "external").symlink_to(external, target_is_directory=True)
        result, = self.invoke([self.candidate(path)])
        self.assert_removed(path, result)
        self.assertEqual((external / "keep.txt").read_text(), "outside data\n")
        with tarfile.open(result["archive"]) as archive:
            self.assertCountEqual(archive.getnames(), [".env", "local-data/external"])
            self.assertEqual(archive.extractfile(".env").read(), b"SYNTHETIC_TOKEN=fixture-only\n")
            self.assertTrue(archive.getmember("local-data/external").issym())
            self.assertEqual(archive.getmember("local-data/external").linkname, str(external))

    def test_detached_commit_is_reachable_through_recovery_ref(self):
        path = self.checkout("detached", detached=True)
        (path / "tracked.txt").write_text("detached work\n")
        self.git("commit", "-am", "Detached commit", cwd=path)
        head = self.git("rev-parse", "HEAD", cwd=path).strip()
        self.assertEqual(self.git("branch", "--contains", head, cwd=self.repo), "")
        result, = self.invoke([self.candidate(path, head=head)])
        self.assert_removed(path, result)
        self.assertIsNone(result["branch"])
        self.assertEqual(self.git("show", result["recovery_ref"] + ":tracked.txt"), "detached work\n")

    def test_two_and_four_workers_remove_distinct_checkouts(self):
        for jobs in (2, 4):
            with self.subTest(jobs=jobs):
                paths = [self.checkout(f"parallel-{jobs}-{i}") for i in range(jobs)]
                results = self.invoke([self.candidate(path) for path in paths], jobs=jobs)
                self.assertEqual(len({row["recovery_ref"] for row in results}), jobs)
                for result in results:
                    self.assert_removed(Path(result["path"]), result)
                    self.assertEqual(self.git("rev-parse", result["branch"]).strip(), self.initial_head)

    def test_active_process_working_directory_is_kept(self):
        path = self.checkout("active")
        process = subprocess.Popen(
            [sys.executable, "-c", "import time; print('ready', flush=True); time.sleep(60)"],
            cwd=path, env=self.env, stdout=subprocess.PIPE, text=True,
        )
        try:
            self.assertEqual(process.stdout.readline(), "ready\n")
            result, = self.invoke([self.candidate(path)])
            self.assertEqual(result["status"], "skipped", result)
            self.assertIn("process", result["detail"])
            self.assertTrue(path.is_dir())
            self.assertIsNone(process.poll())
        finally:
            process.terminate()
            process.wait(timeout=5)
            process.stdout.close()


if __name__ == "__main__":
    unittest.main()

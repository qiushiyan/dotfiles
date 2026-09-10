"""Audit the real CLI against isolated repositories and local bare remotes."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "audit.py"
OLD = 946684800  # 2000-01-01, independent of when this suite runs.


class AuditTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="worktree-audit-test-")
        self.addCleanup(temporary.cleanup)
        self.sandbox = Path(temporary.name).resolve()
        self.root = self.sandbox / "checkouts"
        self.root.mkdir()
        self.home = self.sandbox / "home"
        self.home.mkdir()
        self.hooks = self.sandbox / "empty-hooks"
        self.hooks.mkdir()
        self.bin = self.sandbox / "bin"
        self.bin.mkdir()
        self.env = {
            "PATH": str(self.bin) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "TMPDIR": str(self.sandbox),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TEMPLATE_DIR": str(self.hooks),
            "GIT_TERMINAL_PROMPT": "0",
            "AUDIT_LSOF_LOG": str(self.sandbox / "lsof.log"),
        }
        # Inventory only synthetic processes; never inspect the live session.
        self.stub("lsof", '#!/bin/sh\nprintf "called\\n" >> "$AUDIT_LSOF_LOG"\n'
                  'printf "n%s\\n" "$HOME"\n')
        self.repo, self.remote = self.repository("first")
        self.initial_head = self.git("rev-parse", "HEAD").strip()

    def stub(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o700)

    def command(self, *args, old=False):
        env = dict(self.env)
        if old:
            env.update(GIT_AUTHOR_DATE=f"{OLD} +0000", GIT_COMMITTER_DATE=f"{OLD} +0000")
        return subprocess.run(args, cwd=self.sandbox, env=env, text=True,
                              capture_output=True, check=True, timeout=90)

    def git(self, *args, cwd=None, old=False):
        return self.command("git", "-C", str(cwd or self.repo), *args, old=old).stdout

    def repository(self, name):
        repo = self.sandbox / name
        remote = self.sandbox / (name + ".git")
        self.command("git", "init", "--bare", "-b", "main", str(remote))
        self.command("git", "init", "-b", "main", str(repo))
        self.git("config", "user.name", "Synthetic Test", cwd=repo)
        self.git("config", "user.email", "synthetic@example.invalid", cwd=repo)
        self.git("config", "core.hooksPath", str(self.hooks), cwd=repo)
        (repo / "tracked.txt").write_text("baseline\n")
        (repo / ".gitignore").write_text(".env\nnode_modules/\n")
        self.git("add", ".", cwd=repo)
        self.git("commit", "-m", "Synthetic baseline", cwd=repo, old=True)
        self.git("remote", "add", "origin", str(remote), cwd=repo)
        self.git("push", "-u", "origin", "main", cwd=repo)
        self.git("remote", "set-head", "origin", "--auto", cwd=repo)
        return repo, remote

    def checkout(self, name, *, repo=None, detached=False, old=False):
        path = self.root / name
        flags = ["--detach"] if detached else ["-b", name]
        self.git("worktree", "add", *flags, str(path), "HEAD", cwd=repo, old=old)
        return path

    def divergent(self, name):
        path = self.checkout(name, old=True)
        (path / "tracked.txt").write_text(name + "\n")
        self.git("commit", "-am", "Unmerged work", cwd=path, old=True)
        self.git("push", "origin", "HEAD:refs/heads/" + name, cwd=path)
        self.age_files(path)
        return path

    def age_files(self, path):
        for file in path.rglob("*"):
            os.utime(file, (OLD, OLD), follow_symlinks=False)

    def audit(self, *args):
        output = self.sandbox / "audit.json"
        result = self.command(sys.executable, str(HELPER), str(self.root),
                              "--output", str(output), "--jobs", "2", *map(str, args))
        summary = json.loads(result.stdout)
        report = json.loads(output.read_text())
        self.assertEqual(summary["worktrees"], len(report["worktrees"]))
        self.assertEqual(summary["candidates"], len(report["candidates"]))
        self.assertEqual(summary["kept"], len(report["kept"]))
        self.assertCountEqual(
            [row["path"] for row in report["worktrees"]],
            [row["path"] for row in report["candidates"] + report["kept"]],
        )
        self.assertEqual(report["discovery_errors"], [])
        return report

    def row(self, report, path):
        return next(row for row in report["worktrees"] if row["path"] == str(path))

    def test_fetch_proves_graph_merge_and_audit_preserves_checkout(self):
        self.assertEqual(self.git("config", "--global", "--list"), "")
        self.assertEqual(self.git("config", "core.hooksPath").strip(), str(self.hooks))
        path = self.checkout("merged")
        (path / "tracked.txt").write_text("merged work\n")
        self.git("commit", "-am", "Merged work", cwd=path)
        head = self.git("rev-parse", "HEAD", cwd=path).strip()
        self.git("push", "origin", "HEAD:main", cwd=path)
        self.git("update-ref", "refs/remotes/origin/main", self.initial_head)
        registry = self.git("worktree", "list", "--porcelain")
        report = self.audit()
        self.assertEqual([row["path"] for row in report["candidates"]], [str(path)])
        self.assertEqual(report["candidates"][0]["head"], head)
        self.assertTrue(self.row(report, path)["merged"])
        self.assertTrue(report["repositories"][0]["fresh"])
        self.assertEqual(report["kept"], [])
        self.assertEqual(self.git("worktree", "list", "--porcelain"), registry)
        self.assertEqual((path / "tracked.txt").read_text(), "merged work\n")
        self.assertEqual((self.sandbox / "lsof.log").read_text(), "called\n")

    def test_old_remote_backed_unmerged_tip_is_candidate(self):
        path = self.divergent("old-work")
        report = self.audit()
        row = self.row(report, path)
        self.assertFalse(row["merged"])
        self.assertTrue(row["inactive"])
        self.assertFalse(row["dirty"])
        self.assertIn("refs/remotes/origin/old-work", row["remote_contains"])
        self.assertEqual([item["path"] for item in report["candidates"]], [str(path)])
        self.assertIn("inactive since", report["candidates"][0]["reason"])

    def test_old_commit_with_recent_checkout_or_ignored_file_is_kept(self):
        old_path = self.divergent("old-source")
        self.git("branch", "recent-checkout", "old-source")
        recent = self.root / "recent-checkout"
        self.git("worktree", "add", str(recent), "recent-checkout")
        self.age_files(recent)  # Retain the new HEAD reflog as the only fresh signal.
        (old_path / ".env").write_text("SYNTHETIC=local-data\n")
        report = self.audit()
        self.assertEqual(report["candidates"], [])
        self.assertEqual(len(report["kept"]), 2)
        for path, source in [(recent, "HEAD reflog"), (old_path, ".env")]:
            with self.subTest(path=path):
                row = self.row(report, path)
                self.assertFalse(row["merged"])
                self.assertFalse(row["inactive"])
                self.assertFalse(row["dirty"])
                self.assertEqual(row["activity"]["source"], source)
                self.assertGreater(row["activity"]["timestamp"], time.time() - 60)

    def test_no_fetch_keeps_even_graph_merged_checkout(self):
        path = self.checkout("cached")
        report = self.audit("--no-fetch")
        self.assertEqual(report["candidates"], [])
        self.assertTrue(self.row(report, path)["merged"])
        self.assertFalse(report["repositories"][0]["fresh"])
        self.assertIn("remote evidence not refreshed", report["kept"][0]["reasons"])

    def test_failed_fetch_keeps_even_graph_merged_checkout(self):
        path = self.checkout("fetch-fails")
        self.git("remote", "set-url", "origin", str(self.sandbox / "missing-remote.git"))
        report = self.audit()
        self.assertEqual(report["candidates"], [])
        self.assertTrue(self.row(report, path)["merged"])
        self.assertFalse(report["repositories"][0]["fresh"])
        self.assertTrue(any("fetch origin" in reason for reason in report["kept"][0]["reasons"]))

    def test_narrow_fetch_does_not_prove_backup_of_deleted_remote_branch(self):
        path = self.divergent("deleted-feature")
        head = self.git("rev-parse", "HEAD", cwd=path).strip()
        self.git("config", "remote.origin.fetch", "+refs/heads/main:refs/remotes/origin/main")
        self.git("update-ref", "-d", "refs/heads/deleted-feature", cwd=self.remote)
        report = self.audit()
        # A successful fetch cannot prune a branch excluded from its refspec.
        self.assertEqual(self.git("rev-parse", "refs/remotes/origin/deleted-feature").strip(), head)
        row = self.row(report, path)
        self.assertTrue(row["inactive"])
        self.assertFalse(row["merged"])
        self.assertEqual(row["remote_contains"], [])
        self.assertEqual(report["candidates"], [])
        self.assertEqual([item["path"] for item in report["kept"]], [str(path)])

    def test_narrow_fetch_does_not_make_stale_explicit_base_fresh(self):
        path = self.divergent("advanced-feature")
        head = self.git("rev-parse", "HEAD", cwd=path).strip()
        self.git("config", "remote.origin.fetch", "+refs/heads/main:refs/remotes/origin/main")
        advanced = self.git("commit-tree", "HEAD^{tree}", "-p", head,
                            "-m", "Remote-only advancement", cwd=path).strip()
        # Address the bare remote directly so pushing does not update origin/*.
        self.git("push", str(self.remote), advanced + ":refs/heads/advanced-feature")
        os.utime(path / "tracked.txt", None)
        report = self.audit("--base", "origin/advanced-feature")
        self.assertEqual(self.git("rev-parse", "refs/remotes/origin/advanced-feature").strip(), head)
        row = self.row(report, path)
        self.assertTrue(row["merged"])  # Cached graph ancestry remains evidence.
        self.assertFalse(row["inactive"])
        self.assertFalse(report["repositories"][0]["base_fresh"])
        self.assertEqual(row["remote_contains"], [])
        self.assertEqual(report["candidates"], [])
        self.assertEqual([item["path"] for item in report["kept"]], [str(path)])

    def test_detached_and_multiple_repositories_are_aggregated(self):
        detached = self.checkout("detached", detached=True)
        second, _ = self.repository("second")
        linked = self.checkout("second-linked", repo=second)
        report = self.audit()
        self.assertEqual(len(report["repositories"]), 2)
        self.assertCountEqual([row["path"] for row in report["candidates"]],
                              [str(detached), str(linked)])
        self.assertIsNone(self.row(report, detached)["branch"])
        self.assertEqual(report["kept"], [])

    def test_explicit_repo_finds_missing_registration_without_live_discoveries(self):
        missing = self.checkout("missing")
        shutil.rmtree(missing)
        self.assertEqual(list(self.root.iterdir()), [])
        report = self.audit("--repo", self.repo)
        self.assertEqual(report["candidates"], [])
        self.assertEqual(len(report["worktrees"]), 1)
        self.assertTrue(self.row(report, missing)["missing_checkout"])
        self.assertIn("missing", report["kept"][0]["reasons"][0])
        self.assertIn(str(missing), self.git("worktree", "list", "--porcelain"))

    def test_failed_process_or_git_probe_is_unknown_and_kept(self):
        path = self.checkout("unknown")
        self.stub("lsof", '#!/bin/sh\necho "synthetic inventory failure" >&2\nexit 1\n')
        report = self.audit()
        self.assertEqual(report["candidates"], [])
        self.assertTrue(report["process_error"])
        self.assertNotIn("in_use", self.row(report, path))
        self.assertTrue(any("process inventory" in reason for reason in report["kept"][0]["reasons"]))
        self.stub("lsof", "#!/bin/sh\nexit 0\n")
        self.stub("git", '#!/bin/sh\nif [ "$3" = status ]; then\n'
                  '  echo "synthetic status failure" >&2\n  exit 1\nfi\n'
                  'exec /usr/bin/git "$@"\n')
        report = self.audit()
        self.assertEqual(report["candidates"], [])
        self.assertIsNone(report["process_error"])
        self.assertNotIn("dirty", self.row(report, path))
        self.assertTrue(any("synthetic status failure" in reason
                            for reason in report["kept"][0]["reasons"]))


if __name__ == "__main__":
    unittest.main()

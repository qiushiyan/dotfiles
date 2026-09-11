"""Exercise the installed command against temporary skill trees, never live skills."""

from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[3] / "bin/skill-sync"


class SkillSyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "skills"
        self.root.mkdir()

    def skill(self, name, header="disable-model-invocation: true", metadata=None):
        folder = self.root / name
        folder.mkdir(exist_ok=True)
        (folder / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: A fixture\n{header}\n---\nBody.\n"
        )
        if metadata is not None:
            (folder / "agents").mkdir(exist_ok=True)
            (folder / "agents/openai.yaml").write_text(metadata)
        return folder / "agents/openai.yaml"

    def run_sync(self, *args, expected=0):
        result = subprocess.run(
            [str(SCRIPT), "--skills-dir", str(self.root), *args],
            text=True, capture_output=True, timeout=30,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_check_apply_reenable_and_idempotency(self):
        manual = self.skill("manual")
        automatic = self.skill("automatic", "")
        self.run_sync("--check", expected=1)
        self.assertFalse(manual.parent.exists())
        source = manual.parent.parent / "SKILL.md"
        original = source.read_bytes()
        self.run_sync()
        self.assertIn("allow_implicit_invocation: false", manual.read_text())
        self.assertFalse(automatic.exists())
        self.assertEqual(source.read_bytes(), original)
        stamp = manual.stat().st_mtime_ns
        self.run_sync()
        self.run_sync("--check")
        self.assertEqual(manual.stat().st_mtime_ns, stamp)
        self.skill("manual", "")
        self.run_sync("--check", expected=1)
        self.run_sync()
        self.assertIn("allow_implicit_invocation: true", manual.read_text())
        self.run_sync("--check")

    def test_preserves_metadata_comments_and_permissions(self):
        path = self.skill("manual", metadata=(
            '# Keep this\ninterface:\n  display_name: "Quoted name"\n'
            "policy:\n  other_flag: retained\n  allow_implicit_invocation: true # Keep policy note\n"
            "dependencies:\n  tools: [one, two]\n"
        ))
        path.chmod(0o640)
        self.run_sync()
        text = path.read_text()
        for fragment in ('# Keep this', 'display_name: "Quoted name"',
                         'other_flag: retained', 'tools: [one, two]', '# Keep policy note'):
            self.assertIn(fragment, text)
        self.assertIn("allow_implicit_invocation: false", text)
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)

    def test_yaml_boolean_syntax_and_body_are_distinct(self):
        path = self.skill("manual", '"disable-model-invocation": true # manual')
        automatic = self.skill("automatic", "disable-model-invocation: false")
        with (automatic.parent.parent / "SKILL.md").open("a") as body:
            body.write("\ndisable-model-invocation: true\n")
        self.run_sync()
        self.assertTrue(path.exists())
        self.assertFalse(automatic.exists())

    def test_policy_alias_does_not_change_other_metadata(self):
        path = self.skill("manual", metadata=(
            "defaults: &defaults {allow_implicit_invocation: true}\n"
            "policy: *defaults\n"
        ))
        self.run_sync()
        self.assertRegex(path.read_text(), r"defaults:.*allow_implicit_invocation: true")
        self.assertRegex(path.read_text(), r"policy:.*allow_implicit_invocation: false")
        self.run_sync("--check")

    def test_invalid_input_aborts_before_any_write(self):
        pending = self.skill("a-valid")
        invalid = self.skill("z-invalid", 'disable-model-invocation: "true"')
        self.run_sync(expected=2)
        self.assertFalse(pending.exists())
        self.assertFalse(invalid.exists())
        self.skill("z-invalid", metadata="policy: [false]\n")
        self.run_sync(expected=2)
        self.assertFalse(pending.exists())
        self.skill("z-invalid", metadata="policy: {}\npolicy: {}\n")
        self.run_sync(expected=2)
        self.assertFalse(pending.exists())

    def test_external_links_are_reported_and_preserved(self):
        external = self.base / "external"
        external.mkdir()
        (external / "SKILL.md").write_text(
            "---\nname: linked\ndisable-model-invocation: true\n---\n"
        )
        link = self.root / "linked"
        link.symlink_to(external, target_is_directory=True)
        alias = self.root / "same-folder"
        alias.symlink_to(external, target_is_directory=True)
        result = self.run_sync()
        self.assertIn("[external:", result.stdout)
        self.assertIn("1 skills checked; 1 metadata", result.stdout)
        self.assertTrue(link.is_symlink())
        self.assertIn("allow_implicit_invocation: false",
                      (external / "agents/openai.yaml").read_text())
        self.run_sync("--check")

    def test_linked_metadata_is_updated_at_its_target(self):
        path = self.skill("manual")
        path.parent.mkdir()
        target = self.base / "metadata.yaml"
        target.write_text("interface: {display_name: Original}\n")
        path.symlink_to(target)
        self.run_sync()
        self.assertTrue(path.is_symlink())
        self.assertIn("allow_implicit_invocation: false", target.read_text())

    def test_conflicting_metadata_links_abort(self):
        target = self.base / "metadata.yaml"
        target.write_text("policy: {allow_implicit_invocation: true}\n")
        for name, header in [("manual", "disable-model-invocation: true"), ("auto", "")]:
            path = self.skill(name, header)
            path.parent.mkdir()
            path.symlink_to(target)
        original = target.read_bytes()
        self.run_sync(expected=2)
        self.assertEqual(target.read_bytes(), original)

    def test_broken_links_and_empty_roots_are_errors(self):
        self.run_sync(expected=2)
        link = self.root / "broken"
        link.symlink_to(self.base / "missing", target_is_directory=True)
        self.run_sync(expected=2)
        self.assertTrue(link.is_symlink())
        link.unlink()
        metadata = self.skill("manual")
        missing = self.base / "missing-agents"
        metadata.parent.symlink_to(missing, target_is_directory=True)
        self.run_sync(expected=2)
        self.assertFalse(missing.exists())

    # Document copies: the script's repository is the directory three levels
    # above it, so a copy of the script inside a temporary layout makes that
    # layout the repository and keeps the real manifest out of reach.
    def install(self):
        repo = self.base / "dotfiles"
        script = repo / "scripts/.local/bin/skill-sync"
        script.parent.mkdir(parents=True)
        script.write_bytes(SCRIPT.read_bytes())
        script.chmod(0o755)
        (repo / "docs").mkdir()
        (repo / "docs/standard.md").write_text("# Standard\n\nOne rule.\n")
        return repo, script

    def checkout(self, name, git=True):
        root = self.base / name
        root.mkdir()
        if git:
            (root / ".git").mkdir()
        return root

    def manifest(self, repo, destinations, source="docs/standard.md"):
        path = repo / "scripts/.local/share/dotfiles/documents.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        lines = [f"documents:\n  - source: {source}\n    destinations:\n"]
        for root, target in destinations:
            lines.append(f"      - repo: {root}\n        path: {target}\n")
        path.write_text("".join(lines))
        return path

    def run_script(self, script, *args, expected=0):
        result = subprocess.run([str(script), *args], text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_skills_scope_never_reaches_documents(self):
        self.skill("manual")
        result = self.run_sync()
        self.assertNotIn("documents checked", result.stdout)
        self.assertIn("1 skills checked", result.stdout)

    def test_documents_scope_copies_verbatim_and_reports_external(self):
        repo, script = self.install()
        target = self.checkout("project")
        manifest = self.manifest(repo, [(target, "docs/nested/standard.md")])
        copy = target / "docs/nested/standard.md"
        self.run_script(script, "--documents", str(manifest), "--check", expected=1)
        self.assertFalse(copy.parent.exists())
        result = self.run_script(script, "--documents", str(manifest))
        self.assertIn("[external:", result.stdout)
        self.assertIn("1 documents checked; 1 copies updated", result.stdout)
        self.assertNotIn("skills checked", result.stdout)
        self.assertEqual(copy.read_bytes(), (repo / "docs/standard.md").read_bytes())
        stamp = copy.stat().st_mtime_ns
        self.run_script(script, "--documents", str(manifest))
        self.run_script(script, "--documents", str(manifest), "--check")
        self.assertEqual(copy.stat().st_mtime_ns, stamp)
        copy.write_text("edited locally\n")
        self.run_script(script, "--documents", str(manifest), "--check", expected=1)
        self.run_script(script, "--documents", str(manifest))
        self.assertEqual(copy.read_text(), "# Standard\n\nOne rule.\n")

    def test_default_scope_runs_both_jobs_from_the_repository(self):
        repo, script = self.install()
        for tree in ("claude/.claude/skills/manual", ".claude/skills"):
            (repo / tree).mkdir(parents=True)
        (repo / "claude/.claude/skills/manual/SKILL.md").write_text(
            "---\nname: manual\ndisable-model-invocation: true\n---\n"
        )
        target = self.checkout("project")
        self.manifest(repo, [(target, "docs/standard.md")])
        result = self.run_script(script)
        self.assertIn("1 skills checked; 1 metadata files updated", result.stdout)
        self.assertIn("1 documents checked; 1 copies updated", result.stdout)
        self.assertTrue((repo / "claude/.claude/skills/manual/agents/openai.yaml").exists())
        self.assertTrue((target / "docs/standard.md").exists())
        self.run_script(script, "--check")

    def test_absent_checkout_is_skipped_while_present_ones_sync(self):
        repo, script = self.install()
        present = self.checkout("present")
        absent = self.base / "absent"
        manifest = self.manifest(repo, [(absent, "docs/standard.md"), (present, "docs/standard.md")])
        result = self.run_script(script, "--documents", str(manifest))
        self.assertIn(f"skipped {absent}: checkout absent", result.stdout)
        self.assertTrue((present / "docs/standard.md").exists())
        self.assertFalse(absent.exists())
        self.run_script(script, "--documents", str(manifest), "--check")

    def test_invalid_manifest_aborts_every_job_before_writes(self):
        repo, script = self.install()
        skills = repo / "claude/.claude/skills"
        (skills / "manual").mkdir(parents=True)
        (skills / "manual/SKILL.md").write_text("---\nname: manual\ndisable-model-invocation: true\n---\n")
        metadata = skills / "manual/agents/openai.yaml"
        target = self.checkout("project")
        bad = [
            [(target, "../escape.md")],
            [(target, "/tmp/absolute.md")],
            [(self.checkout("plain", git=False), "docs/standard.md")],
            [(target, "docs/standard.md"), (target, "docs/standard.md")],
        ]
        for destinations in bad:
            manifest = self.manifest(repo, destinations)
            self.run_script(script, "--skills-dir", str(skills), "--documents", str(manifest), expected=2)
            self.assertFalse(metadata.exists())
            self.assertFalse((target / "docs/standard.md").exists())
        manifest = self.manifest(repo, [(target, "docs/standard.md")], source="docs/missing.md")
        self.run_script(script, "--documents", str(manifest), expected=2)
        (target / "docs").mkdir()
        link = target / "docs/standard.md"
        link.symlink_to(repo / "docs/standard.md")
        manifest = self.manifest(repo, [(target, "docs/standard.md")])
        self.run_script(script, "--documents", str(manifest), expected=2)
        self.assertTrue(link.is_symlink())
        link.unlink()
        (repo / "scripts/.local/share/dotfiles/documents.yaml").write_text("documents: []\n")
        self.run_script(script, "--documents", str(manifest), expected=2)


if __name__ == "__main__":
    unittest.main()

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


if __name__ == "__main__":
    unittest.main()

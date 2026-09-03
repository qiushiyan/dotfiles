# Vendored Claude bundled skills

Satellite of `docs/agent-skills.md`. Read this when a Claude Code built-in must
remain available while `disableBundledSkills` is enabled, or when refreshing an
existing vendored copy.

## Model

Claude's bundled-skill kill switch is all-or-nothing. A user skill with the same
name shadows its bundled counterpart and is unaffected by the switch, so the
supported exception is a real directory under `claude/.claude/skills/`.

```text
bundled skill required + kill switch enabled
  → extract current bundled body
  → place real directory under claude/.claude/skills/<name>
  → add Codex symlink only when Codex should also receive it
  → record why the copy exists
```

`artifact-design` is vendored because the Artifact tool requires it while the
tool itself remains enabled. Discover the current inventory from the skills
tree and git rather than copying a count here.

## Refresh

The body is embedded in the installed Claude CLI binary as a template literal.
After an upgrade that touches artifacts:

1. Locate the template by its frontmatter (`name: artifact-design`); minifier
   variable names are not stable.
2. Read the binary directly and decode the template literal.
3. Compare the extracted body with the tracked directory.
4. Remove runtime placeholders whose feature flag is disabled.
5. Re-read the skill and verify invocation before committing.

Do not extract through `strings`: its minimum-length filter drops short lines,
including blank lines and the `---` frontmatter fence, and silently corrupts the
document.

`<!-- dataviz-callout -->` is a runtime placeholder, not skill content. The CLI
substitutes it only behind the dataviz feature flag; remove it when that feature
is unavailable so the skill does not route to a disabled dependency.

## Completion check

```text
real directory under claude/.claude/skills/
no divergent Codex copy
reason for vendoring still true
body matches the current CLI source
frontmatter and pointers render intact
```

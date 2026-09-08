# Claude bundled skills

Claude maintains the bundled artifact skills and their supporting files.
`claude/.claude/settings.json` owns the selection: artifact design and
diagramming are model-invocable; workshop and dataviz are user-invocable
only. The other bundled skills have explicit `off` overrides. Built-in
prompt commands and doctor remain manual-only, matching their availability
under the global kill switch.

## Settings boundary

`disableBundledSkills` stays false. The global switch removes bundled skills
before `skillOverrides` can enable them; it has no per-skill exemption.
`CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1` has the same effect. The separate tool
deny list, workflow disablement, and connector disablement stay in force.

Overrides use exact skill names, including for personal skills; they are not
scoped to the bundled source. Use the canonical `code-review` name to hide
that bundled skill; `review` belongs to our personal skill. Plugin skills
are controlled through plugins and can be invoked by their qualified name.

`workshop` and `dataviz` stay out of the model's skill listing until explicitly
invoked with `/workshop` or `/dataviz`. Their content then enters the session.
The upstream artifact instructions can still mention them. In particular,
artifact-design can direct Claude to dataviz when a feature flag is enabled;
that reference does not bypass the manual-only override. Invoke `/dataviz`
explicitly when chart guidance is needed. Feature-gated skills remain subject
to their upstream availability gates even when an override permits invocation.

## Upstream ownership and upgrades

Keep bundled skill names out of the personal skill directory: a personal copy
shadows the native one. Claude loads bundled bodies and extracts supporting
files when needed, into its temporary directory under a build-specific path.
The artifact-design body itself has no supporting-file bundle.

After a Claude Code upgrade, inspect `/skills` in a fresh session and set new
unwanted bundled names to `off` in the global settings. Unlisted names default
to `on`; there is no supported bundled-only wildcard or allowlist. The `/skills`
menu saves overrides to project-local settings, so use the global file for
machine-wide policy. The inventory lives in Claude and the selection in
settings, rather than in this document.

## Verification

In a fresh session, confirm the artifact skills use the bundled source and no
personal artifact-design directory exists. Check that unwanted skills are off,
`/workshop` and `/dataviz` remain manual-only when available, and personal
`/review` plus project overrides still work. A skill-loading check should
confirm native artifact-design instructions load without publishing an artifact.
For a headless check, opt that process into artifacts with
`CLAUDE_CODE_ARTIFACT=1`; the SDK default otherwise withholds the Artifact
tool and its dependent skills. Keep that opt-in local to the check.

References: [skill overrides](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings),
[skill precedence](https://code.claude.com/docs/en/skills#where-skills-live).

# Bundled skill visibility

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

## Codex controls

Codex distinguishes its runtime-owned `~/.codex/skills/.system/`, plugin
skills, and the shared personal tree. Claude-imported copies under
`claude/.claude/skills/synced/` belong to that personal tree: the Codex
bundled switch does not cover them. Preserve the shared directory;
Codex-only visibility choices belong in `codex/.codex/config.toml`.

The [local-skill configuration](https://learn.chatgpt.com/docs/build-skills#enable-or-disable-local-codex-skills)
can hide a skill without deleting its files. Codex CLI 0.154.0 also supports
an exact name selector, which covers every same-named copy:

```toml
[[skills.config]]
name = "morning"
enabled = false

[[skills.config]]
name = "import-memory"
enabled = false
```

These are optional examples, not the current selection. Name rules also
match personal skills with the same name. To distinguish a bundled or
imported copy from a retained personal skill, use `path` instead of `name`,
pointing to its exact `SKILL.md`. CLI 0.154.0 expands `~` and resolves
symlinks; folder, subtree, and glob exclusions are unsupported. The config
reference's folder wording is misleading: a folder override leaves the
skill visible. A synced-tree exclusion therefore needs one file rule per
copy and a fresh inventory after imports.

`[skills.bundled]` with `enabled = false` removes the `.system` skills while
preserving the shared tree. It has no per-skill exemption: an `enabled = true`
rule cannot restore a skill whose system root was excluded. Name selection
and the bundled switch are present in the
[configuration implementation](https://github.com/openai/codex/blob/main/codex-rs/config/src/skills_config.rs);
the behaviors above are verified against the installed CLI 0.154.0.

For manual invocation with no default catalog entry, use
`policy.allow_implicit_invocation: false` in the skill's `agents/openai.yaml`.
`docs/agent-skills.md` owns the shared-skill synchronization procedure.
CLI 0.154.0 has no equivalent per-skill policy in `config.toml`; strict
configuration validation rejects it. Editing runtime-owned or imported
metadata is vulnerable to its owner's refresh, so use external disable
rules when preserving manual invocation is unnecessary.

[Plugin enablement](https://learn.chatgpt.com/docs/config-file/config-reference)
uses `[plugins."plugin-name@marketplace-name"]` with `enabled = false`, or
the plugin browser. This controls the plugin's capabilities, including its
MCP servers; use a skill rule when the tools should remain available.
Workspace-managed enablement can override local plugin choices.

## Verifying Codex visibility

`codex debug prompt-input` renders the model-visible initial messages
without a model request. Compare fresh invocations before and after an
override; preserve the live configuration by testing overrides in a
temporary `CODEX_HOME` or with process-local `-c` flags. Manual-only skills
should disappear from the catalog while remaining explicitly invocable;
disabled skills should disappear from both discovery and invocation.
Recheck the actual desktop session after changing its configuration:
the CLI probe establishes CLI behavior, not every desktop-managed surface.

The context saving is the skill's name, description, and path. Full bodies
already load only when selected. Existing conversation context remains;
start a fresh session to measure the reduction. See
[progressive disclosure and invocation](https://learn.chatgpt.com/docs/build-skills).

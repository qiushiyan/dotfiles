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

Claude's sync cache uses organization/account subdirectories. Codex discovers
each cached copy through the shared tree without applying Claude's active-account
selection. The sync manifests identify `morning` and `import-memory` as
`anthropic-example`; these are Anthropic-provided cloud skills. See
[claude.ai skill syncing](https://code.claude.com/docs/en/skills#where-synced-skills-load).

The policy in `scripts/.local/share/dotfiles/skill-policy.yaml` excludes the
Claude cloud cache and selected Codex system skills. `skill-sync` generates
[local-skill configuration](https://learn.chatgpt.com/docs/build-skills#enable-or-disable-local-codex-skills)
using exact `SKILL.md` paths, preserving same-named personal and plugin skills.
Run it after cloud imports and skill/runtime updates. The generated selection
belongs to the marked block in `codex/.codex/config.toml`; the synchronization
contract lives in `docs/agent-skills.md` § Synchronizing Codex invocation.

Codex CLI 0.154.0 expands `~` and resolves symlinks in path selectors. Folder,
subtree, and glob exclusions are unsupported: a folder override leaves the
skill visible. Its name selector matches every same-named copy, so use that
only when all copies should be disabled. The manifest's exclusion-root rule
is implemented by enumerating files, not by passing a directory to Codex.

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
metadata is vulnerable to its owner's refresh. The tracked policy lets
`skill-sync` restore manual-only metadata without forking skill bodies.

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

### Catalog measurement

Capture the same prompt, model, working directory, and CLI version before and
after changing policy:

```bash
codex debug prompt-input 'Skill catalog measurement' > /tmp/skill-prompt.json
```

Count the `### Available skills` portion of the `<skills_instructions>` text,
ending before `</skills_instructions>`. This includes every emitted name,
description, and path; the larger block also includes the root aliases and
instructions. Count text rather than JSON escaping. `tiktoken` with
`o200k_base` gives a reproducible estimate, not the serving model's exact token
usage. Catalog budgeting can change description lengths, so compare emitted
text rather than subtracting file sizes.

The 2026-09-17 CLI 0.154.0 measurement in dotfiles used `gpt-6-astra`. The
baseline already excluded morning and import-memory. The policy pass measured:

| Measure | Before | After |
|---|---:|---:|
| Default catalog entries | 70 | 31 |
| Catalog characters | 21,416 | 12,045 |
| Catalog tokens, o200k estimate | 6,128 | 2,767 |
| Entire skills block, o200k estimate | 6,357 | 2,996 |

The catalog reduction is approximately 3,361 tokens (54.8%); this is a share
of skill context, not of the whole model window. App-server `skills/list`
confirms manual-only skills remain enabled and excluded copies are disabled.
The desktop-bundled CLI 0.153.4 cannot render this configuration because it
rejects the existing `tui.keymap.chat.prompt_stack_back` field. These numbers
therefore measure the standalone CLI, not a desktop session or a billed API
request.

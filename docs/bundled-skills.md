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

Codex discovers runtime-owned `~/.codex/skills/.system/`, plugin skills,
and shared personal skills. Claude cloud downloads under the shared tree's
`synced/` directory are a separate owner but visible through the same path.
The Codex bundled switch covers only `.system`. The tracked policy supplies
the desired selection; `codex/.codex/config.toml` and per-skill metadata are
the derived controls.

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

Verification has separate boundaries:

- `skill-sync --check` checks generated files against policy, without writing.
- `codex debug prompt-input` renders that CLI's default catalog without a
  model request. Manual-only and disabled skills should be absent.
- App-server `skills/list` reports availability: manual-only skills remain
  enabled; excluded copies can still appear here with `enabled: false`.
- A fresh desktop process must supply a catalog with the same exclusions;
  manual invocation needs its own check. A CLI probe does not establish either.

Use a temporary `CODEX_HOME` or process-local `-c` flags for experimental
overrides. Keep verification tied to the executable and configuration used.

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
of skill context, not of the whole model window. The standalone app-server
reports manual-only skills enabled and excluded copies disabled; no model
request exercised manual invocation.
The desktop-bundled CLI 0.153.4 cannot render this configuration because it
rejects the existing `tui.keymap.chat.prompt_stack_back` field. These numbers
therefore measure the standalone CLI, not a desktop session or a billed API
request. Desktop exclusion verification remains open: the running session's
refreshed catalog still contains the excluded system and cloud skills while
omitting the manual-only entries. A fresh desktop process has not been checked,
and the cause of that discrepancy is not established.

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
invoked with `/workshop` or `/dataviz`. The upstream artifact instructions can
still mention them — artifact-design can direct Claude to dataviz when a
feature flag is enabled — but that reference does not bypass the manual-only
override, so invoke `/dataviz` explicitly when chart guidance is needed.
Feature-gated skills remain subject to their upstream availability gates even
when an override permits invocation.

## Upstream ownership and upgrades

Keep bundled skill names out of the personal skill directory: a personal copy
shadows the native one.

After a Claude Code upgrade, inspect `/skills` in a fresh session and set new
unwanted bundled names to `off` in the global settings. Unlisted names default
to `on`; there is no supported bundled-only wildcard or allowlist. The `/skills`
menu saves overrides to project-local settings, so use the global file for
machine-wide policy.

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
and shared personal skills — including every Claude cloud download under the
shared tree's `synced/` cache, one copy per organization/account, without
Claude's active-account selection
([claude.ai skill syncing](https://code.claude.com/docs/en/skills#where-synced-skills-load)).
The Codex bundled switch covers only `.system`. The tracked policy supplies the
selection and `skill-sync` derives
[local-skill configuration](https://learn.chatgpt.com/docs/build-skills#enable-or-disable-local-codex-skills)
from it; `docs/agent-skills.md` § Synchronizing Codex invocation owns that
contract.

The exact-path design rests on Codex CLI 0.154.0 behaviour, verified against
the installed CLI and its
[configuration implementation](https://github.com/openai/codex/blob/main/codex-rs/config/src/skills_config.rs):

- Path selectors expand `~` and resolve symlinks, but folder, subtree and glob
  exclusions are unsupported — a folder override leaves the skill visible, so
  exclusion roots are enumerated into files.
- The name selector matches every same-named copy; use it only when all copies
  should be disabled.
- `[skills.bundled]` with `enabled = false` removes the `.system` skills while
  preserving the shared tree, with no per-skill exemption: `enabled = true`
  cannot restore a skill whose system root was excluded.
- Strict validation rejects a per-skill invocation policy in `config.toml`.

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

The saving is each hidden skill's name, description, and path
([progressive disclosure](https://learn.chatgpt.com/docs/build-skills)); a
running conversation keeps what it already has, so measure in a fresh session.

**Open: the desktop app.** Its bundled CLI 0.153.4 cannot render this
configuration (it rejects the existing `tui.keymap.chat.prompt_stack_back`
field). A running desktop session's refreshed catalog still listed the
excluded system and cloud skills while omitting the manual-only entries; a
fresh desktop process and manual invocation remain unchecked, and the cause is
not established.

### Catalog measurement

Capture the same prompt, model, working directory, and CLI version before and
after changing policy:

```bash
codex debug prompt-input 'Skill catalog measurement' > /tmp/skill-prompt.json
```

Count the `### Available skills` portion of the `<skills_instructions>` text,
ending before `</skills_instructions>`, as text rather than JSON escaping.
`tiktoken` with `o200k_base` gives a reproducible estimate, not the serving
model's exact usage. Catalog budgeting can change description lengths, so
compare emitted text rather than subtracting file sizes.

On the standalone CLI 0.154.0 the policy cut the default catalog from 70 to
31 entries, about 55% of the catalog's estimated tokens — a share of skill
context, not of the model window.

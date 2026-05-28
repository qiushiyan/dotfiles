This folder is a Stow package for **TabType**, a text-expansion tool. `.config/tabtype/config.json` is the live config — it's symlinked to `~/.config/tabtype/config.json` by the parent dotfiles Stow setup, so edits here change the running app immediately.

The `snippets` array holds the prompt templates the user pastes into AI coding tools (Claude Code, Codex, etc.) via the `;;` trigger. These snippets — not TabType itself — are the substance of the file, and most work future agents do here will be revising or adding them. They encode a deliberate two-agent, three-stage development workflow.

## The workflow encoded by the snippets

The user runs two coding agents in parallel: one **implementer** (drafts specs, plans, code) and one **reviewer** (critiques each artifact). Snippets get pasted between them. The three stages are **spec → plan → implementation**, each with its own draft / review / update cycle:

| Stage          | Sent to implementer                                               | Sent to reviewer                          |
| -------------- | ----------------------------------------------------------------- | ----------------------------------------- |
| Spec           | `draft-spec`, `update-spec`                                       | `review-spec`                             |
| Plan           | `tdd-plan` / `tdd-plan-strict` / `start-plan`, `update-plan`      | `review-plan`, `review-plan-updates`      |
| Implementation | `review-reflect` (analyze reviewer feedback before changing code) | `review-implementation`, `review-updates` |

`tdd-plan` is the default planning snippet; `tdd-plan-strict` uses literal red-green-refactor per behavior; `start-plan` is the non-TDD fallback.

Standalone snippets that don't belong to a single stage:

- **Pre-stage analysis**: `think-holistic`, `list-assumptions`, `trace-execution`
- **Cross-agent coordination**: `compare-notes` (synthesize two agents' analyses), `commits-summary` (handoff context block)
- **Wrap-up**: `pr-description`, `find-similar-bugs`
- **Reference / meta**: `refactor-guidelines` (delegates to `~/.claude/skills/refactoring/`), `smart-adapt-skills`, `technical-difficulty`

## Design patterns to preserve

When revising or adding snippets, these patterns recur and carry the workflow's intent:

**Stage altitude lens** (in `review-spec`, `review-plan`). Each artifact has a deliberate level of detail. The reviewer is given a three-part lens so they critique at the right altitude:

1. Vagueness about things the artifact _intentionally_ defers — don't ask for more.
2. Vagueness about things the artifact _should_ answer — flag it.
3. Technical content the artifact _does_ propose — fair game to critique; propose better.

What counts as "intentional" differs by stage:

- **Spec** defers line-level edits, specific test cases, doc plans, and commit order.
- **Plan** defers _only_ full code bodies. Test cases, helper internals, fixture shape, and line-level references for existing code _are_ in the plan and are reviewable.

**"What not to include" guardrails** (in `draft-spec`, `tdd-plan`). Each draft snippet explicitly names what gets designed at a _later_ stage, to stop the agent from prematurely committing to details (e.g., the spec doesn't include doc-update plans because those happen post-implementation).

**Round-2 review** (`review-updates`, `review-plan-updates`). Re-check after the drafter applies feedback — focus is "was the concern actually addressed, or hand-waved?" Apply the same altitude lens; don't relitigate settled points.

**Reflect-before-change for code feedback** (`review-reflect`). The drafter analyzes critique _before_ touching code. Spec/plan use direct `update-*` snippets since text is cheap to revise; code uses the reflect pattern because code changes are more expensive.

## Snippet schema

```json
{ "key": "snippet-name", "expand": "text with \\n newlines and $0 cursor" }
```

- `key` triggers via `;;key`; the `;;` trigger is set under `settings.trigger`.
- `expand` is a JSON string — newlines as `\n`, slashes can be `\/` or `/`, quotes escaped.
- `$0` marks where the cursor lands after expansion (used wherever the user is about to paste reviewer feedback: `update-*`, `review-reflect`, `review-plan-updates`).
- `---\n\n$0` is the convention for snippets that need a visual separator before the pasted content.

Naming convention: stage artifacts follow `draft-X` / `review-X` / `update-X` / `review-X-updates`. Standalone snippets use descriptive names (`think-holistic`, `find-similar-bugs`).

## Editing

Edits to `.config/tabtype/config.json` are live in TabType immediately via the Stow symlink — no reload needed. After editing, validate JSON:

```bash
python3 -c "import json; json.load(open('.config/tabtype/config.json'))"
```

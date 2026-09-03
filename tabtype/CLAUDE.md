# TabType prompt snippets

This Stow package owns the live TabType config at
`tabtype/.config/tabtype/config.toml`. Edits take effect immediately.

The `snippets` array is the product: prompt templates pasted into Claude Code,
Codex, and other coding agents through the `;;` trigger.

## Model

```text
reason about the problem → settle a design → plan tactics → implement → review
         optional peer input ↗                         ↘ handoff or cleanup
```

`WORKFLOW.md` owns the order and invocation of snippets. `DESIGN.md` owns the
prompt patterns and altitude rules. Read only the branch being edited.

## Invariants

- **Artifact altitude:** the spec owns behavior, boundaries, target shape, and
  test strategy; the plan owns slices, cases, fixtures, and line-level anchors;
  implementation owns code bodies.
- **Design before tactics:** `design-it-twice` runs while shaping the spec, not
  after an interface has already been committed.
- **Independent judgment:** an author does not supply the only review of its
  design or code. A report or handoff orients the reviewer; it does not grade
  the work.
- **Reflect before expensive change:** code-review responses assess findings and
  test implications before editing. Narrow round-two fixes may apply inline.
- **Context follows the next phase:** compaction keeps what the next action
  consumes and drops the journey that produced it.

## Snippet schema

```toml
[[snippets]]
key = "snippet-name"
expand = '''
text with literal newlines
and $0 cursor'''
```

- `key` expands through `;;key`.
- `expand` uses a TOML literal multiline string; the closing `'''` sits on the
  last content line to avoid an extra newline.
- `$0` marks pasted input or the final cursor position.
- A blank line, `---`, then `$0` separates instructions from pasted material.

Names describe direction:

```text
write-X / start-X / implement-X → author creates
review-X                        → reviewer judges
update-X / respond-X            → author integrates feedback
*-again                         → convergence pass
*-status / *-handoff            → context for another agent
```

## Editing

Treat the config as the inventory: search its `key =` lines rather than copying
the list into this file. After editing:

```bash
python3 -c "import tomllib; tomllib.load(open('tabtype/.config/tabtype/config.toml', 'rb'))"
```

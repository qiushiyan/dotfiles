# Claude context chip — design

Satellite of `tmux/.config/tmux/workflow.md`. Read this when changing the Claude
statusline, quota cache, pane-border lifecycle, or responsive shedding.

## Flow

```text
Claude statusline payload ─┬→ context + model + 5-hour
headroom quota cache ──────┘
            ↓
statusline-command.sh publishes pane options
            ↓
tmux.conf renders the pane border

SessionEnd / zsh precmd / pane-exited / pane move
            → tmux-claude-ctx.sh → clear or reconcile
```

The pane options are the boundary:

```text
@claude_ctx          context percentage; existence gate for the chip
@claude_ctx_model    reported model, updated after /model
@claude_ctx_account  quota lane
@claude_ctx_5h       five-hour usage
@claude_ctx_wk       model-scoped weekly usage
@claude_ctx_wk_model weekly model label
```

The statusline republishes only changed values. `tmux-claude-ctx.sh` is the
single owner of turning the border off.

## Quota sources

```text
5-hour        → Claude statusline payload
model weekly  → headroom limits → ~/.cache/claude-ctx/<lane>.quota
render path   → shell-builtin cache read; never waits for headroom
```

Claude's payload exposes an all-models weekly number, not the model-scoped limit
that normally stops work. A detached refresher updates the scoped cache after
five minutes when no sibling pane owns the lock.

An aged value is safe while its usage window is live because usage only rises.
After the window rolls over, stale low usage would promise headroom that may not
exist, so the number disappears. An untrusted zero is never published.

## Identity and layout

The account is the quota lane, not the process owner. Extra accounts come from
the `CLAUDE_CONFIG_DIR` chosen by headroom; the primary comes from
`~/.claude.json`. Use the email local part unless two lanes share it, then use
the full email. A config directory outside `~/.claude-accounts/` uses its
basename.

Fields are ordered by scope:

```text
account  5h  model-weekly  model  context
lane facts ←──────────────→ session facts
```

Responsive shedding preserves the signal that matters:

```text
<75 columns → calm quota pair drops
<55         → account drops
<40         → model drops
always      → context remains
quota ≥50   → survives to 40
quota ≥85   → survives at any width
```

Each quota value earns its own colour: muted below 50, yellow from 50, red from
90. The context percentage follows the same attention scale.

## Lifecycle

Cleanup has overlapping owners because exits are incomplete signals:

- Claude `SessionEnd` handles normal exits.
- zsh `precmd` catches hard kills; a suspended Claude process remains live.
- tmux `pane-exited` handles closed panes.
- break, join, and move paths reconcile after relocation.

A per-pane tombstone prevents the last in-flight render of a dying session from
resurrecting its chip. It lasts only until that conversation starts again;
`SessionStart` discharges it so same-pane resume works.

## Verification

```text
publisher: claude/.claude/commands/statusline-command.sh
control:   tmux/.config/tmux/scripts/tmux-claude-ctx.sh
render:    tmux/.config/tmux/tmux.conf, "pane borders"
tests:     tmux/.config/tmux/scripts/tests/test-claude-context-chip.sh
```

Exercise a full-width pane, half split, quarter split, urgent quota, hard kill,
same-pane resume, and pane relocation. The suite must substitute the quota
refresher so it never touches the live accounts cache.

# Claude context chip — design

Satellite of `tmux/.config/tmux/workflow.md`. Read this when changing the Claude
statusline, quota cache, pane-border lifecycle, or responsive shedding.

## Flow

```text
Claude statusline payload ─┬→ context + model + 5-hour
headroom quota cache ──────┘
            ↓
statusline-command.sh sources tmux-agent-status.sh,
publishes pane options through agent_claude_publish
            ↓
tmux.conf renders the pane border

SessionStart / SessionEnd / zsh precmd / codex wrapper / pane-exited / pane move
            → tmux-agent-status.sh → activate, clear, sweep, or reconcile
```

## Ownership

One script owns per-pane agent status: `tmux-agent-status.sh`. The option
names are defined once in `lib/agent-vocab.sh`, which the owner, the
statusline (through the owner), and the zsh prompt sweep read. Producers say
*when* — a render, a hook, a prompt, a Codex launch — and the owner says
*which options* change:

```text
activate claude | codex    SessionStart discharge; Codex launch
clear claude | codex       SessionEnd (owner-checked); Codex exit
sweep <pane> [agent...]    the prompt returned: drop, tombstoning Claude's sid
reconcile [target]         the only path that turns the border row off
done / recount             dormant agent-done badge (agent-notify.md)
```

The render path has a budget: one server-side `if-shell` per render, no
process spawned. The statusline therefore *sources* the owner and calls its
spawn-free builder instead of running a verb. The zsh prompt keeps one tmux
round trip per prompt: `cout`'s precmd, which runs after oh-my-posh's, carries
its own publication and the sweep's presence test in a single call, and the
owner's `sweep` is spawned only when an agent's marker is actually set.
`tmux.conf` stays the renderer and names the options it draws; the chip suite
checks that every name it reads is one the vocabulary publishes.

The Claude options themselves, the boundary between the statusline and the
border (the owner's header documents each one's semantics):

```text
@claude_ctx          context percentage; existence gate for the chip
@claude_ctx_model    reported model, updated after /model
@claude_ctx_account  quota lane
@claude_ctx_5h       five-hour usage
@claude_ctx_wk       model-scoped weekly usage
@claude_ctx_wk_model weekly model label
```

The statusline republishes only changed values. `tmux-agent-status.sh
reconcile` is the single owner of turning the border off.

## Quota sources

```text
5-hour        → Claude statusline payload
model weekly  → headroom limits → ~/.cache/claude-ctx/<lane>.quota
render path   → shell-builtin cache read; never waits for headroom
```

Claude's payload exposes an all-models weekly number, not the model-scoped limit
that normally stops work. A detached refresher updates the scoped cache after
five minutes when no sibling pane owns a fresh lock. Locks older than two
minutes allow a refresher through so its stale-lock sweep can recover from an
interrupted run.

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

The model-scoped weekly has priority over the 5-hour figure on every account,
even at low usage. Responsive shedding follows pane width:

```text
<140 columns → 5-hour drops
<55          → account drops
<40          → model drops; weekly drops below 85%
always       → context remains
weekly ≥85   → survives at any width
```

Each quota value earns its own colour: muted below 50, yellow from 50, red from
90. The context percentage follows the same attention scale.

## Lifecycle

Cleanup has overlapping owners because exits are incomplete signals:

- Claude `SessionEnd` handles normal exits.
- zsh `precmd` catches hard kills; a suspended Claude process remains live. The
  same sweep backs up the Codex wrapper's own exit cleanup.
- tmux `pane-exited` handles closed panes.
- break, join, and move paths reconcile after relocation.

A per-pane tombstone prevents the last in-flight render of a dying session from
resurrecting its chip. It lasts only until that conversation starts again;
`SessionStart` discharges it so same-pane resume works.

## Verification

```text
publisher:  claude/.claude/commands/statusline-command.sh
vocabulary: tmux/.config/tmux/scripts/lib/agent-vocab.sh
owner:      tmux/.config/tmux/scripts/tmux-agent-status.sh
prompt:     zsh/.config/zsh/tmux-utils.zsh, cout.zsh
render:     tmux/.config/tmux/tmux.conf, "pane borders"
tests:      tmux/.config/tmux/scripts/tests/test-claude-context-chip.sh
```

Exercise full-width and split panes across accounts, including low weekly
usage beside urgent 5-hour usage. Cover abandoned-lock recovery, hard kill,
same-pane resume, and pane relocation. Stub the refresher for trigger checks;
stub `headroom` and use a temporary home when exercising the real refresher,
so tests never touch the live accounts cache.

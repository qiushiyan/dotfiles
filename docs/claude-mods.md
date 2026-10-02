# Claude Code mods

A mod is a plugin of function hooks: a TypeScript module Claude Code keeps
loaded for the whole session, which can observe or rewrite events, keep state,
draw a band or pane, and register slash commands. Skills stay the home for
anything the model reads, and for anything Codex shares; a mod is for what the
harness itself should do or show. Authoring is the bundled `plugin-authoring`
skill's; this doc owns where mods live here and how they reach every account.

## Where a mod lives and how it loads

```text
claude/.claude/mods/<name>/     tracked source, stowed as ~/.claude/mods
claude/.claude/settings.json    env.CLAUDE_CODE_PLUGIN_DIRS names each mod folder
```

`CLAUDE_CODE_PLUGIN_DIRS` loads each listed folder exactly as `--plugin-dir`
would, in every session, interactive or `claude -p`. Every account dir links
the same `settings.json` (`docs/claude-accounts.md` § Model — the filesystem is the registry), so the one line
is the whole multi-account story: no launcher, wrapper or per-account step
takes part. A second mod is a second path in the same value, separated by `:`.

The alternative this beats is a marketplace install. `plugins/` is per-account
runtime state, so an installed plugin has to be installed once per account and
again for each new one, while its `enabledPlugins` entry in the shared settings
claims it is on everywhere.

Interactive sessions watch the folder, so a saved edit reloads the mod in every
running session on every account.

The settings value replaces a `CLAUDE_CODE_PLUGIN_DIRS` set in the process
environment, so a mod not yet listed is tried with the flag, which adds to the
list: `claude --plugin-dir ~/.claude/mods/<name>`.

## Traps

- **A failing hook is skipped, and the chain continues without it.** Outside a
  session that hot-reloads the folder, the only sign is the debug log
  (`claude --debug`). A guard that must not fail open stays a settings hook;
  `block-dangerous-git.py` is one.
- **The engine writes into the mod folder at every load:**
  `.claude-plugin/types/`, which carries its own ignore-all `.gitignore`, and a
  `tsconfig.json` beside the manifest, which is tracked.
- **`$.store` belongs to the config dir, so it is per account.** A mod's
  shared defaults are constants in its source; what it stores is that
  account's override.
- **The mods switch is rolled out per account and cached.** An account that
  has not been used since the rollout can refuse on its first run with
  `hooks module not loaded: … the rollout switch served off` and load on the
  next.
- **The API is early access and moves between releases.** After a Claude Code
  update, run the checks below; the laid `.claude-plugin/types/` is the
  authority for the installed build.
- **A command cannot run another command from inside its `command.run` hook.**
  The engine refuses: it would wait on the turn the hook is holding. The hook
  answers, and a `$.clock.after(0, …)` callback runs the second command.
- **The dock shows one pane, and the engine's diff panel keeps it once a
  session has edits.** A mod's pane is then not visible, while the engine
  still reports it shown. A mod's always-on surface is the band, and a command
  that opens a pane also prints its content.

## Checks

Run from a scratch directory (`docs/testing.md`). The test kit runs each test
in the engine's own sandbox with no filesystem, network or process.

```bash
claude plugin validate ~/.claude/mods/<name>   # manifest, hooked events, $ calls
claude plugin test ~/.claude/mods/<name>       # the mod's tests/*.test.ts
claude -p '/did' < /dev/null                   # steps answers: the mod loaded here
```

To check another account, run the last line with `CLAUDE_CONFIG_DIR` set to
its dir; a refusal prints the reason on the first line.

What a headless run cannot show is checked in an interactive session on its
own tmux server, driven with `send-keys` and `capture-pane`
(`tmux -L <name> -f /dev/null`): a band or pane as drawn, a toast, and `/cd`,
which a `claude -p` session does not have. A `claude` started from inside a
session inherits `TMUX` and `TMUX_PANE`: unset both first. A child that falls
back to the `enter-worktree` skill runs `session-cd`, which types into the
pane it was handed.

## steps

`claude/.claude/mods/steps` answers "did we run X this session?". It records
which skills and TabType snippets ran, shows them in a band above the prompt,
and keeps the record through compaction, where the model's own memory of the
session is least reliable. The header of `hooks/register.tsx` owns the
mechanism; `hooks/detect.ts` owns the signal rules and the judge's prompt.

- **`/steps`:** the full record in a pane and as text. `/steps pin <name>` and
  `/steps unpin <name>` change which steps the band shows even when they have
  not run; `/steps clear` empties the record.
- **`/did <question>`:** asks a fork of the session with the record attached.
  With no question it prints the record and calls no model.
- **A pinned step appears only where it exists,** as a skill or snippet of
  that project, so `pl-loopy-verify` shows in PlanLab and nowhere else.
- **A name in a prompt is not a run.** A skill expanded or a snippet pasted
  counts at once; a bare name counts as named only. One Haiku call per turn
  that had a candidate then reads the prompt, tool calls and final answer and
  can overturn either reading. A step it marks started is re-read on later
  turns until it finishes.
- **Snippets are matched by their opening text** in
  `~/.config/tabtype/config.toml`, so a snippet needs no marker; one too short
  to be distinctive is never tracked. The office mini stows the `tabtype`
  package for this file: TabType runs on the laptop, and its snippets reach
  the mini as text pasted over ssh.

## quota

`claude/.claude/mods/quota` says what the tmux context chip cannot
(`tmux/.config/tmux/scripts/context-chip.md`). The chip draws each window's
fill and is stateless; the mod keeps a session's readings, which arrive pushed
whenever a window moves a whole point.

- **A window is announced once per threshold,** 75% and 90%, as a toast. The
  90% one also stays as a transcript line and names the account with the most
  room, read from `headroom limits`, which reads its cache from disk and
  spends no request.
- **A pace is given only when it matters:** when, at the rate of the last 45
  minutes, the window fills before it resets.
- **A session that starts on a nearly spent lane says so** at its first
  reading. Usage only rises inside a window, so a lower reading starts the
  window's history and alerts over.
- **`/quota`:** this session's windows with reset and pace, then the board
  (`headroom accounts --compact`, a live read). No model is called.

## worktree

`claude/.claude/mods/worktree` gives `/wt`, which puts the session in a new
worktree without a turn of the main model. A fork of the session picks the
branch from the conversation and the repository's recent branch names, `gwt`
creates it, `/cd` moves the session, and the instruction typed with `/wt` is
then submitted as the person's next prompt, so the work starts in the worktree
at once.

- **`/wt <instruction>`:** "create a worktree and go fix it". The fork also
  says whether the instruction asks for anything beyond the worktree; only
  then is it submitted.
- **`/wt <branch> [base]`:** a branch typed out, recognised by its slash, is
  taken as written and no model is asked.
- **The `enter-worktree` skill stays.** It does the same through a full turn,
  and its move lands only when that turn ends, so it cannot go on to the work
  in the same turn. Codex has only the skill.
- **A failure is reported and nothing is forced:** no usable branch from the
  fork, a `gwt` refusal, or a refused move each print what happened and what
  to type.

## Sessions already running

`CLAUDE_CODE_PLUGIN_DIRS` is read when a process starts, so a session that
was running before the line or a mod's folder arrived loads nothing until it
restarts; resuming it (`x-select`, `x --resume`) keeps the conversation. On
that first load `steps` reads the transcript and records what it shows ran:
by signals alone, so those steps read `unjudged`, and from the newest rows the
engine returns, so the start of a very long session can be missing.

`~/.claude/mods` is one link to the package's `mods/` directory: `make restow`
makes it on the laptop, and `mini-sync` restows the mini
(`docs/qiushi-mini.md` § Sync).

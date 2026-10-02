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

## Checks

Run from a scratch directory (`docs/testing.md`). The test kit runs each test
in the engine's own sandbox with no filesystem, network or process.

```bash
claude plugin validate ~/.claude/mods/<name>   # manifest, hooked events, $ calls
claude plugin test ~/.claude/mods/<name>       # the mod's tests/*.test.ts
claude -p '/did'                               # steps answers: the mod loaded here
```

To check another account, run the last line with `CLAUDE_CONFIG_DIR` set to
its dir; a refusal prints the reason on the first line.

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
  to be distinctive is never tracked.

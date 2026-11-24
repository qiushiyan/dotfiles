# Antigravity CLI (agy)

Google's Antigravity CLI, `agy`, is how Gemini models are reached here, on the
Google AI Ultra plan. This doc is how it is installed, how its settings stay in
the repository though `agy` rewrites them, and why every folder is trusted.

## Install and sign-in

The `antigravity-cli` cask is in the `Brewfile`'s desk section, so the laptop
and mini2 have it and the office mini does not. Homebrew owns its updates:

```bash
brew upgrade --cask antigravity-cli      # not `agy update`; the cask disables it
```

The `antigravity` cask is the desktop app, a different product; nothing here
needs it.

The sign-in is per machine: run `agy` once at that machine's screen and finish
the browser login. Credentials live in the macOS keychain, never in a carried
or tracked file, and every later run, headless `agy -p` included, reuses them.

Use only `agy` itself with that login. A proxy or third-party tool that reuses
its OAuth token is what Google suspends Antigravity accounts for.

## Settings: rendered by twin, never a link

`agy` replaces `~/.gemini/antigravity-cli/settings.json` every time it starts:
it rewrites the file in its own format, drops any key left at its default, and
a symlink there becomes a plain file. So the file is rendered by
`twin dotfiles apply` on each machine, the way the Codex config is
(`docs/twin.md` § Codex config):

```text
twin/.config/twin/agy/shared.json      every machine
twin/.config/twin/agy/<machine>.json   laid over it on that machine, key by key
~/.gemini/antigravity-cli/settings.json  twin writes the source's keys; every other key is agy's
```

The source owns only the keys it sets. Everything else stays `agy`'s and is
kept on each render: the folders trusted at a prompt, rules saved from a
permission prompt, the Google Cloud sign-in. A key the source stops setting
is removed from the file, so `agy`'s default returns. `twin`'s
`internal/dotfiles` owns the render (`renderAgy`), and its
`TestDotfilesApplyRendersAgySettings` guards these rules.

Two traps:

- **Set only values that differ from agy's defaults.** `agy` deletes a key
  left at its default, and a missing owned key reads as a local edit.
- **Effort is part of the model's name.** `agy` 1.5.10 rejects an `effort`
  key (`--settings: unknown setting "effort"`), so the source sets
  `"model": "Gemini 4 Neon (High)"`, the user's pick over Neon's XHigh;
  `agy models` lists the names. The command line takes model and effort
  apart (`--model gemini-4-neon --effort high`) and never reads the
  settings' effort, so a command that names the model names the effort too.

A change made inside `agy`, `/model` or `/config` on an owned key, is drift
and stops the next apply:

```text
mac dotfiles: agy drift — ~/.gemini/antigravity-cli/settings.json was edited locally: model
```

```bash
$EDITOR twin/.config/twin/agy/shared.json && twin dotfiles apply   # keep it: move it into the source
twin dotfiles apply --replace-agy-settings                         # or discard it
```

A machine where `agy` has never run has no `~/.gemini/antigravity-cli`, and
nothing renders there until the apply after its first run.

## Full autonomy, as in Claude Code and Codex

The user chose to run `agy` with the autonomy Claude Code and Codex have here
(Codex's `danger-full-access` with `approval_policy = "never"`). Edits
are accepted, shell, web and MCP tools proceed without asking, the agent may
work outside the folder it started in, and nothing waits on a plan review.
`agy`'s own default mode, `auto`, runs commands in the macOS sandbox, and the
source leaves it. No deny rules are set, matching the other two CLIs.

## Every folder is trusted

`agy` asks "Do you trust the contents of this project?" in each folder it
starts in. On 1.5.10 the answer covers that exact folder only: a trusted parent
covers nothing below it, no pattern matches, and neither a setting nor
`--dangerously-skip-permissions` turns the question off. `workspace-trust`
cannot help either, since it records repository roots and `agy` asks again in
every subfolder.

So `agy()` in `zsh/.config/zsh/agy.zsh` passes the launch folder as trusted
through `--settings`. That flag applies to one session and `agy` never saves
it, so nothing piles up in the settings file. The function covers shells only.
A headless run (`agy -p`) never asks, so a program that calls the binary
directly needs nothing. envoy is one: it runs `agy` as a provider, which the
consult skill dispatches as a Neon voice (`~/dev/envoy/docs/providers.md`).

## What stays out of the repository

`~/.gemini` holds `agy`'s conversations, history and caches. Nothing is stowed
into it, which is why it is not one of the Makefile's `REAL_DIRS`. A package
that starts linking a file there (a global `~/.gemini/AGENTS.md`, say) must
add `~/.gemini` to `REAL_DIRS` first (`docs/stow-layout.md`). `twin` never
carries `~/.gemini` between machines, the same as `~/.claude` and `~/.codex`.

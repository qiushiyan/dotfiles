# Stow layout — what gets symlinked, and what must not

How this repo maps onto `$HOME`, and the two places where getting it wrong
publishes live runtime state into a public repo without raising an error.

## The model

Each top-level directory is a Stow package whose internal tree mirrors a path
under `$HOME`. Stow symlinks **per item**, not per package: given
`claude/.claude/settings.json`, it creates `~/.claude/` as a real directory and
links only `settings.json` into it. That per-item behavior — Stow calls it
folding — is the whole safety property, and it holds only while the target
directory already exists.

`PACKAGES` in the Makefile is `*/` minus `docs/` and `vpn-private/`, so
repo-only documentation and the gitignored local backup are never stowed.

## Directories that must stay real

`~/.claude`, `~/.codex` and `~/.config/lazygit` are listed in `REAL_DIRS` in the
Makefile, and `make install` / `make restow` `mkdir -p` them *before* running
`stow`. That ordering is the enforcement: Stow folds a package into an existing
directory, but links the whole directory when it is absent.

If one of them became a single symlink to its package, everything the app writes
at runtime would start landing inside this repo:

```
~/.claude/     history.jsonl, sessions/, projects/, telemetry/, plugins/, caches
~/.codex/      sqlite DBs, sessions/, caches — and auth.json, a live credential
```

The repo is public, so `~/.codex/auth.json` alone makes this a credential leak.
Nothing errors at the time; the files simply appear as untracked additions.

**Defense in depth:** the `.gitignore` blocks for both packages ignore
`<pkg>/.<app>/*` wholesale and then allow-list only the config that belongs in
git. A folded directory would still be wrong, but its runtime state would not be
committable by accident.

## `<pkg>/CLAUDE.md` stows to `~/CLAUDE.md`

A `CLAUDE.md` at a package root goes to `~/CLAUDE.md`, the global user memory
prepended to every request in every project on this machine — so package-local
guidance written there becomes permanent context for unrelated work everywhere.

Two rules follow:

- **`claude/.claude/CLAUDE.md` stays empty.** It stows to `~/.claude/CLAUDE.md`,
  which is that same global memory. Document Claude configuration in an ordinary
  `docs/` file instead, and link it from the map in the root `CLAUDE.md`.
- **Package-local guidance needs a `.stow-local-ignore` entry.** TabType lists
  `CLAUDE.md`, `WORKFLOW.md`, and `DESIGN.md`, so its repo-local docs stay out of
  `$HOME`. Any package adding a root-level instruction or satellite must add the
  corresponding ignore before restowing.

## Adding a file

Use the `dotadd` zsh function rather than moving files by hand — it places the
file in the right package and stows it in one step.

# Zsh configuration

Package: `zsh/` → `~/.zshrc`, `~/.zshenv`, `~/.config/zsh/`.

## The three startup files

Which file a change belongs in is most of the work, because each runs for a
different kind of shell:

- **`.zshenv`** — _every_ zsh invocation, including scripts and `ssh host cmd`.
  Sets `typeset -U path`, puts Homebrew on `PATH` (guarded and idempotent — the
  system `/etc/zprofile` only fires for login shells, so `ssh host cmd` and
  mosh-server would otherwise miss it), forces a UTF-8 locale for the same
  reason, sources `toolchain.zsh`, then sources every other
  `~/.config/zsh/*.zsh` so functions and aliases exist everywhere.
- **`.zprofile`** — login shells only. Homebrew + OrbStack `shellenv`.
- **`.zshrc`** — interactive shells only. oh-my-zsh, syntax highlighting,
  completions, Oh My Posh prompt, fzf/zoxide, the lazy `nvm` stub.

They load `.zshenv` → `.zprofile` → `.zshrc`.

**`~/.zprofile` is not in this repo.** Homebrew's and OrbStack's installers wrote
it and own it, so it is machine-local state that `make install` does not
recreate — a new machine gets it from running those installers, not from
stowing. It matters to the load order anyway: its unconditional `brew shellenv`
runs _after_ `toolchain.zsh` and re-prepends Homebrew's paths, which is exactly
why `.zshrc` re-asserts `$NVM_BIN` at the front of `PATH` to keep nvm's Node
ahead of any Homebrew `node`.

## Modules

Sourced by `.zshenv`; `toolchain.zsh` first, then the rest in glob order.

```
zsh/.config/zsh/
  toolchain.zsh    # cheap PATH setup (default Node via nvm, no subprocess)
  aliases.zsh
  git.zsh          # aliases + the deferred completion registration
  nav.zsh
  utils.zsh        # gitclean, loc, ccclean, n, take, dotadd, …
  theme.zsh        # the $TERMINAL_THEME switch
  claude.zsh       # multi-account launchers (x, x-<name>) — see claude-accounts.md
  claude-sessions.zsh  # shared session store: migration + drift check (tests/ has its harness)
  xcode.zsh
  tmux-utils.zsh
  proxy.zsh
  gws.zsh
```

## Toolchain conventions

- **Node** — nvm, default `lts/*`, lazy-loaded (below). `toolchain.zsh` resolves
  the default version's `bin` into `$NVM_BIN` without spawning a subprocess.
- **Python** — `python` is a _function_ delegating to `command python3`
  (Homebrew's), never an alias, so an active virtualenv still wins.
- **Package manager** — pnpm preferred over npm.
- **Editing** — `set -o vi`; vim keybindings everywhere.
- **Secrets** — `~/.secrets`, untracked, mode `600`, sourced by `.zshrc`.

## Lessons learned

Hard-won during a startup-perf and robustness pass. Read before editing.

- **Reload with `exec zsh`, never `source ~/.zshrc`.** Re-sourcing only _adds_
  state; it cannot drop deleted aliases, functions, or exports, nor fix stale
  in-memory state. `zshreload` is aliased to `exec zsh -l`.
- **`.zshenv` must exit 0.** A non-zero last statement silently breaks
  `source ~/.zshenv && …` chains. Keep the final line a clean `if`, not a
  short-circuiting `&&`.
- **nvm is lazy-loaded.** Eagerly sourcing `nvm.sh` costs ~230 ms per shell.
  `toolchain.zsh` already puts the default Node on `PATH` cheaply; an `nvm()`
  stub in `.zshrc` loads the real nvm on first call. Don't reinstate eager
  `source nvm.sh`.
- **`typeset -U path`** (in `.zshenv`) keeps `$PATH` duplicate-free no matter how
  often the config is sourced.
- **Functions, not aliases, for real command names.** Aliases resolve before
  `$PATH`, so `alias python=…` shadows virtualenvs; `python` and `make` are
  functions for this reason. Start non-trivial functions with `emulate -L zsh`
  so ambient options can't change their behavior.
- **Completions register late.** `compdef` exists only after oh-my-zsh runs
  `compinit`. `git.zsh` is sourced once, by `.zshenv`, which stubs `compdef` out
  to suppress errors; `.zshrc` calls `_git_zsh_register_completions` afterward.
  Don't re-source whole files just to register completions.
- **Measure, don't guess.** Profile with `zmodload zsh/zprof`; verify a perf
  change with an _interleaved_ A/B benchmark (`git stash` the change, time both
  back-to-back, repeat) — not before/after numbers taken minutes apart. This
  pass took startup ~530 ms → ~160 ms.

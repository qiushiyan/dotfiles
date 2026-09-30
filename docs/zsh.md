# Zsh configuration

Package: `zsh/` → `~/.zshrc`, `~/.zshenv`, `~/.zlogin`, `~/.config/zsh/`.

## Startup files

Which file a change belongs in is most of the work, because each runs for a
different kind of shell:

- **`.zshenv`** — _every_ zsh invocation, including scripts and `ssh host cmd`.
  Sets `typeset -U path`, puts Homebrew on `PATH` (guarded and idempotent — the
  system `/etc/zprofile` only fires for login shells, so `ssh host cmd` and
  mosh-server would otherwise miss it), forces a UTF-8 locale for the same
  reason, sources `toolchain.zsh`, then sources every other
  `~/.config/zsh/*.zsh` so functions and aliases exist everywhere, then this
  machine's host file (§ Machines), then global options such as `EQUALS` off.
  It must end with status 0 (§ Lessons learned).
- **`.zprofile`** — login shells only. Homebrew + OrbStack `shellenv`.
- **`.zshrc`** — interactive shells only. oh-my-zsh, syntax highlighting,
  completions, Oh My Posh prompt, fzf/zoxide, the lazy `nvm` stub.
- **`.zlogin`** — login shells only, after the other startup files. Reapplies
  the shared tool paths so login profiles cannot shadow the selected Node.

They load `.zshenv` → `.zprofile` → `.zshrc` → `.zlogin`, skipping files that
do not apply to the shell's mode.

**`~/.zprofile` is not in this repo.** Homebrew's and OrbStack's installers
write and own it, so a new machine gets it from those installers, not from
`make install`. Its unconditional `brew shellenv` runs _after_ `.zshenv` and
re-prepends Homebrew's paths, so `.zshrc` reapplies `toolchain.zsh` after
plugin setup and `.zlogin` does for login shells, including non-interactive
`zsh -lc`. It also exports `FPATH`, which `.zshrc` undoes (§ Completion dump).

`toolchain.zsh` owns CLI install directories for every shell mode. Add new
tool paths there, not to a static `PATH` in Codex's `shell_environment_policy`:
Codex inherits its environment and `.zshenv` supplies the paths even when the
app starts from the GUI (`docs/codex-zsh-path-command-not-found.md`).

## Modules

Sourced by `.zshenv`; `toolchain.zsh` first, then the rest in glob order.

```
zsh/.config/zsh/
  toolchain.zsh    # shared CLI paths, pnpm globals, default Node via nvm
  aliases.zsh
  git.zsh          # git aliases, worktree helpers, the one git() wrapper
  nav.zsh          # jumps and pulls: p/pp [--cd] (planlab checkout + handoff briefs), y, fcd
  utils.zsh        # loc, dotadd, cpwd, the mobile `agents` session, …
  theme.zsh        # the $TERMINAL_THEME switch
  cwd-guard.zsh    # deleted-cwd defenses: _cwd_guard at startup, zshreload (tests/ has its harness)
  claude.zsh       # multi-account launchers (x, x-<name>) — see claude-accounts.md
  claude-sessions.zsh  # shared session store: migration + drift check (tests/ has its harness)
  codex.zsh        # Codex accounts through headroom (cx, cx-<name>); plain `codex` stays the vendor default
  xcode.zsh
  tmux-utils.zsh   # Codex border wrapper, prompt agent-status sweep, tmux-wait-for-text
  cout.zsh        # execution boundaries for the cout recorder (~/dev/cout)
  proxy.zsh
  hosts/<machine>.zsh  # one machine's identity (§ Machines); outside the glob
  tests/           # suites (docs/testing.md); outside the glob
```

## Machines

The laptop and the office mini (`docs/qiushi-mini.md`) stow this same
package, so both run one `.zshenv`, `.zshrc` and `.zlogin` and every module.
A new module reaches every machine without a list to update. Two rules keep
that working:

- **Check for the tool, not the machine.** A line that needs something a
  machine may lack guards on it: `[[ -r ~/.cargo/env ]]`, or a `(N/)` glob
  qualifier on a completion directory. The GCP variables are set only where `gcloud` is
  installed, and the lazy `nvm` stub loads Homebrew's nvm or the installer's
  copy, whichever exists. A `toolchain.zsh` PATH entry for a directory a
  machine lacks is a harmless miss. A module that only defines functions
  (`xcode`, `proxy`) needs no guard: its functions just fail where the tool is
  absent.
- **Only identity is per machine.** What is about being a particular
  machine, such as its prompt badge or its SSH client quirks, goes in
  `hosts/<name>.zsh`. `.zshenv` sources it last, in every shell, when the
  untracked one-word `~/.config/machine` names it, so it can override a
  module. A machine without a marker, currently the laptop, loads no host
  file. A marker naming a missing file warns in interactive shells only,
  since stderr in a non-interactive shell lands in tool output.
  `$HOST` is not the key because the mini reports a DHCP name (`Mac.lan`).

Per-machine state stays out of both: `~/.secrets`, `~/.zprofile`, logins,
and headroom's generated account launchers. `tests/portability.test.zsh`
starts the package on a bare `$HOME` and fails on startup noise, a module
that did not load, or a host file that did not load from its marker.

## Toolchain conventions

- **Node** — nvm, default `lts/*`, lazy-loaded (below). `toolchain.zsh` resolves
  the default version's `bin` into `$NVM_BIN` without spawning a subprocess.
- **Python** — `python` is a _function_ delegating to `command python3`
  (Homebrew's), never an alias, so an active virtualenv still wins.
- **Package manager** — pnpm preferred over npm.
- **Editing** — `set -o vi`; vim keybindings everywhere.
- **Secrets** — `~/.secrets`, untracked, mode `600`, sourced by `.zshrc`.

## Completion dump

oh-my-zsh keeps compinit's dump in `~/.zcompdump-<host>-<version>` and deletes
it whenever the fpath recorded there differs from the current one; a rebuild
adds 200–350 ms to that shell's start. So `.zshrc` gives every interactive shell
the same fpath before it sources oh-my-zsh: it drops inherited `$ZSH/*`
entries, deduplicates (`typeset -U`), pins Homebrew's and OrbStack's
completion directories, and unexports `FPATH`.

The export is the trap. `brew shellenv` runs `export FPATH`, so without the
unexport a child shell (nested `zsh`, `zshreload`, a tmux pane whose server
captured the variable) inherits its parent's oh-my-zsh entries and adds them
again; each such context has a different fpath and rewrites the shared dump.
The pinned directories are the ones only login shells add, through
`~/.zprofile`; without the pin a non-login shell lacks `brew`, `docker` and
`orb` completions and records yet another fpath. A new completion directory belongs in that pin,
guarded with `(N/)`, not on an exported `FPATH`. `tests/portability.test.zsh`
checks that an inherited `FPATH` changes nothing and does not leak.

## Copying a command and its output

`cout [N]` and tmux `prefix o` copy a completed command and its terminal output
to the clipboard of the machine you sit at, through `toclip` when it is
installed (over SSH to the mini, the laptop's; `docs/qiushi-mini.md`
§ Clipboard and attach), else `pbcopy`; `cout --print N` writes the same text
to stdout for agents. Usage belongs to `tmux/.config/tmux/workflow.md`
§ Reading back & copying output (copy mode).

The engine is the `cout` CLI (`~/dev/cout`, installed in `~/.local/bin` and
copied to the mini by `mini-sync`). Its README owns the pane's `pipe-pane`
recorder, the marker protocol, completed records and indexes, retention and
its limits, and replay.

`zsh/.config/zsh/cout.zsh` owns execution boundaries and shell identity:
`preexec` saves the exact command text and marks the start, `precmd`/`zshexit`
mark the end, and `zsh/.zshrc` registers these hooks after Oh My Posh consumes
the exit status. Standalone copies and empty or cancelled prompts create no
record. The `precmd` also carries the prompt's tmux round trip
(`tmux/.config/tmux/scripts/context-chip.md` § Ownership).

Every active execution receives output, so a parent `zsh` or `ssh` record
contains the nested interaction; a local child shell has its own index, and
`exec zsh` starts a new one. Shared history and prompt themes do not determine
boundaries.

Copying renders an immutable record in a temporary, isolated tmux server without
rerunning the command, so clearing or resizing the live pane leaves completed
records intact; replay uses the dimensions at command start. Full-screen output,
a lost replay boundary, and oversized or incomplete records are refused with the
clipboard unchanged.

Recordings live under `${XDG_CACHE_HOME:-~/.cache}/cout` (700/600); oldest
records expire first. Leave cleanup to the recorder: deleting an active cache
interrupts recording and prompts for a reload, and setup refuses to replace
another logger.

`zshreload` picks up changed shell hooks but reuses the pane's live recorder,
so a new `cout` build or changed retention needs a new pane. After a recorder
failure, reload the shell and run a new command to resume capture; earlier
output is gone. The isolated suite is in `docs/testing.md`.

## Lessons learned

Read before editing.

- **Reload with `zshreload`, never `source ~/.zshrc`.** Re-sourcing only
  _adds_ state; it cannot drop deleted aliases, functions, or exports.
  `zshreload` is `exec zsh -l` behind a cwd check, because a zsh started in a
  deleted directory freezes the pane at the first keystroke
  (`cwd-guard.zsh`'s header has the mechanism and both defenses).
- **`.zshenv` must end with status 0.** A non-zero last statement silently
  breaks `source ~/.zshenv && …` chains, so whatever comes last is a plain
  command or a complete `if`, never a short-circuiting `&&`.
- **nvm is lazy-loaded.** Eagerly sourcing `nvm.sh` costs ~230 ms per shell.
  `toolchain.zsh` already puts the default Node on `PATH` cheaply; an `nvm()`
  stub in `.zshrc` loads the real nvm on first call. Don't reinstate eager
  `source nvm.sh`.
- **`typeset -U path`** (in `.zshenv`) keeps `$PATH` duplicate-free no matter how
  often the config is sourced.
- **Functions, not aliases, for real command names.** Aliases resolve before
  `$PATH`, so `alias python=…` shadows virtualenvs; `python` is a
  function for this reason. Start non-trivial functions with `emulate -L zsh`
  so ambient options can't change their behavior.
- **Completions register late.** `compdef` exists only after oh-my-zsh runs
  `compinit`, so a module sourced by `.zshenv` defers registration to a
  function `.zshrc` calls afterward (`_git_zsh_register_completions`). Don't
  re-source whole files just to register completions.
- **A function in `.zshrc` replaces a module's function of the same name**,
  because `.zshrc` runs after `.zshenv` sourced the modules; a second `git()`
  there silently disables `git.zsh`'s branch guard in interactive shells.
  Extend the module's function instead; `tests/portability.test.zsh` checks
  that `git()` comes from `git.zsh`.
- **Autosuggestions bind their widgets once**, at the first prompt
  (`ZSH_AUTOSUGGEST_MANUAL_REBIND=1` in `.zshrc`, which says why it is safe).
  A widget created later gets no suggestion handling until
  `_zsh_autosuggest_bind_widgets` runs.
- **`EQUALS` expansion is off, machine-wide** (`unsetopt EQUALS` in
  `.zshenv`, whose comment has the mechanism). With it on, an agent's
  bash-flavoured `cat a; echo ====; cat b` **aborts the rest of the eval'd
  line** — `cat b` never runs, and the only clue is one error line. It lives in
  `.zshenv` because the shells that hit it are non-interactive, and `.zshenv`
  also reaches sessions running against a stale Claude shell snapshot. A
  script that wants the default back uses `emulate zsh` or `zsh -f`; `=(...)`
  process substitution is unaffected. Pinned by
  `zsh/.config/zsh/tests/startup-options.test.zsh`.
- **Measure, don't guess.** Profile with `zmodload zsh/zprof`; verify a perf
  change with an _interleaved_ A/B benchmark (`git stash` the change, time both
  back-to-back, repeat) — not before/after numbers taken minutes apart.

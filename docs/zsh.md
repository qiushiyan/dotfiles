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
  `~/.config/zsh/*.zsh` so functions and aliases exist everywhere, and finally
  turns `EQUALS` expansion off (below).
- **`.zprofile`** — login shells only. Homebrew + OrbStack `shellenv`.
- **`.zshrc`** — interactive shells only. oh-my-zsh, syntax highlighting,
  completions, Oh My Posh prompt, fzf/zoxide, the lazy `nvm` stub.
- **`.zlogin`** — login shells only, after the other startup files. Reapplies
  the shared tool paths so login profiles cannot shadow the selected Node.

They load `.zshenv` → `.zprofile` → `.zshrc` → `.zlogin`, skipping files that
do not apply to the shell's mode.

**`~/.zprofile` is not in this repo.** Homebrew's and OrbStack's installers wrote
it and own it, so it is machine-local state that `make install` does not
recreate — a new machine gets it from running those installers, not from
stowing. It matters to the load order anyway: its unconditional `brew shellenv`
runs _after_ `.zshenv` and re-prepends Homebrew's paths. `.zshrc` reapplies
`toolchain.zsh` after plugin setup; `.zlogin` covers login shells, including
non-interactive `zsh -lc` calls.

`toolchain.zsh` owns CLI install directories for every shell mode. Add new
tool paths there. Codex's `shell_environment_policy` inherits its parent
environment without a static `PATH` override; `.zshenv` supplies the tool
paths even when the app starts from the macOS GUI. A hard-coded Codex path
list drifts as tools are installed. Parent inheritance alone cannot import
exports or virtual environments activated in another terminal after startup.

For diagnosis and recovery, see
[Codex: CLI works in the terminal but is not found](codex-zsh-path-command-not-found.md).

## Modules

Sourced by `.zshenv`; `toolchain.zsh` first, then the rest in glob order.

```
zsh/.config/zsh/
  toolchain.zsh    # shared CLI paths, pnpm globals, default Node via nvm
  aliases.zsh
  git.zsh          # git aliases, gopen/worktree helpers (also tmux prefix g), deferred completion registration
  nav.zsh          # n, take, drop, y, fcd, p/pp (planlab checkout; PLANLAB_DIR)
  utils.zsh        # gitclean, loc, n, take, dotadd, …
  theme.zsh        # the $TERMINAL_THEME switch
  cwd-guard.zsh    # deleted-cwd defenses: _cwd_guard at startup, zshreload (tests/ has its harness)
  claude.zsh       # multi-account launchers (x, x-<name>) — see claude-accounts.md
  claude-sessions.zsh  # shared session store: migration + drift check (tests/ has its harness)
  xcode.zsh
  tmux-utils.zsh
  cout.zsh        # cout + execution boundaries for the pane recorder
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

## Copying a command and its output

`cout [N]` copies the Nth most recent completed command and displayed output
to the macOS clipboard (default 1). tmux `prefix o` copies the latest command.
Both report a 40-character command preview after a successful copy. The workflow and limits are in
[tmux's copy guide](../tmux/.config/tmux/workflow.md#reading-back--copying-output-copy-mode).

`cout.zsh` defines the wrapper in every shell, but `.zshrc` registers its hooks
only for interactive tmux shells, after Oh My Posh has consumed the command's
exit status. Recorder setup is lazy: the first real command initializes it,
keeping Python startup off the shell-startup path. Each shell gets its own
session ID. `preexec` saves exact command text and emits a private start marker; `precmd`/`zshexit` emit its end marker.
Standalone `cout` calls and empty/cancelled prompts create no record. Shared
Zsh history and prompt themes are not involved.

One `tmux pipe-pane` recorder per pane observes output and these ordered markers.
It owns completed records, indexes, and retention; the shell publishes only its
session and expected completion ID. A reader waits for that exact completion
before selecting an index, so recorder lag cannot silently select an older
command. Each active execution receives output: a parent `zsh` command includes
the nested interaction, while child commands have their own records. Returning
from the child restores the parent's index. `exec zsh` starts a new index; its
first command finalizes the replaced shell's interrupted execution as incomplete. Remote prompt markers do not
change local command boundaries; an `ssh` command records the entire connection.

The helper renders a selected recording in a temporary, isolated tmux server,
joins wrapped lines, and copies terminal text without rerunning the command.
Completed recordings survive changes to the live pane's size or scrollback.
Full-screen output and recordings whose beginning was erased during rendering
are refused. Rendering uses the pane dimensions at command start; resizing
*during* a running interactive program may affect its layout.

Recordings live under `${XDG_CACHE_HOME:-~/.cache}/cout`, with private directories
and files (700/600). Each active command has a 16 MiB output limit; completed
records share a 64 MiB output budget and 1,000-record limit per pane. Oldest
completed records are pruned first, across all shell sessions. Oversized output
is flagged rather than silently truncated. The recorder removes its cache on
clean pipe closure. A recorder fault preserves completed files; the next setup reaps
caches abandoned by dead recorders. Removing an active cache stops its recorder;
the shell reports one reload instruction without repeating internal errors.
An existing non-cout output pipe is left alone and setup reports the conflict.

Existing shells need `zshreload` and a newly run command. Copying while a command
is running, from an old shell protocol, or after recorder failure leaves the
clipboard unchanged and reports the problem.

## Lessons learned

Hard-won during a startup-perf and robustness pass. Read before editing.

- **Reload with `exec zsh`, never `source ~/.zshrc`.** Re-sourcing only _adds_
  state; it cannot drop deleted aliases, functions, or exports, nor fix stale
  in-memory state. `zshreload` (`cwd-guard.zsh`) is `exec zsh -l` behind a cwd
  check: a zsh started inside a deleted directory gets `PWD="."`, and
  zsh-syntax-highlighting then spins forever on `.:h == .` at the first
  keystroke — the pane looks frozen. The function first moves to the nearest
  ancestor that still exists; `_cwd_guard` catches every other way of starting
  a shell there (moves to `~`).
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
  `$PATH`, so `alias python=…` shadows virtualenvs; `python` is a
  function for this reason. Start non-trivial functions with `emulate -L zsh`
  so ambient options can't change their behavior.
- **Completions register late.** `compdef` exists only after oh-my-zsh runs
  `compinit`. `git.zsh` is sourced once, by `.zshenv`, which stubs `compdef` out
  to suppress errors; `.zshrc` calls `_git_zsh_register_completions` afterward.
  Don't re-source whole files just to register completions.
- **`EQUALS` expansion is off, machine-wide** (`unsetopt EQUALS`, last line of
  `.zshenv`). By default zsh expands any word starting with `=` to the path of
  that command — `=ls` → `/bin/ls`, on assignment right-hand sides and
  colon-separated components too, so `x==ls` assigns `/bin/ls` and `p=a:=ls:b`
  becomes `a:/bin/ls:b`. All of that is now literal. It was disabled because AI
  agents write bash-flavoured one-liners into this shell: `cat a; echo ====;
  cat b` made zsh look up a command named `===`, and since the tool `eval`s the
  whole string, the failure **aborted the rest of the line** — `cat b` never
  ran, and the only clue was one error line under otherwise correct output.
  947 truncated tool calls across 260 sessions before it was traced. `.zshenv`
  rather than `.zshrc` because every shell that hits it is non-interactive, and
  `.zshenv` is also read by sessions already running against a stale Claude
  shell snapshot. Escape hatches for a script that wants the default back:
  `emulate zsh`, or `zsh -f` to skip startup files entirely. `=(...)` process
  substitution is a different feature and is unaffected. Pinned by
  `zsh/.config/zsh/tests/startup-options.test.zsh`.
- **Measure, don't guess.** Profile with `zmodload zsh/zprof`; verify a perf
  change with an _interleaved_ A/B benchmark (`git stash` the change, time both
  back-to-back, repeat) — not before/after numbers taken minutes apart. This
  pass took startup ~530 ms → ~160 ms.

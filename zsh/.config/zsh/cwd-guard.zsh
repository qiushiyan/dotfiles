# ~/.config/zsh/cwd-guard.zsh — shells whose working directory was deleted.
# Auto-sourced by .zshenv via ~/.config/zsh/*.zsh glob.
#
# Delete the directory a shell sits in — `git worktree remove`, `gwt` cleanup,
# an rm -rf from another pane — and that shell keeps running fine on an
# unlinked inode. The trouble starts when a NEW zsh is started there, which is
# exactly what `exec zsh -l` (zshreload) does, in place. getcwd(3) fails, zsh
# cannot validate the inherited $PWD against `.`, and settles on PWD="." with
# no way left to recover the real path. The tell is the row of
#   shell-init: error retrieving current directory: getcwd: cannot access ...
# lines: every bash that startup spawns (brew shellenv, tmuxifier) prints one.
#
# PWD="." is then fatal for an interactive shell: zsh-syntax-highlighting's path
# check (main-highlighter.zsh, the ZSH_HIGHLIGHT_DIRS_BLACKLIST walk) climbs
# `$PWD/<word>` with the :h modifier until it reaches `/` — and `.:h` is `.`,
# so the first keystroke that forms a word spins the shell at 100% CPU with the
# pane unresponsive. Sampled stack: zle-line-init → _omp_zle-line-init →
# recursive-edit → zle-line-pre-redraw → _zsh_highlight → that while loop.
# Upstream z-sy-h has no fix as of 2026-08 (0.8.1-dev).
#
# Two defenses, one on each side of the exec:
#   _cwd_guard      the NEW shell, from .zshenv: PWD is not absolute → cd ~
#                   before any prompt, so zle never sees a "." cwd. Interactive
#                   shells only — a script started in a dead directory has no
#                   zle to hang, and must not have its cwd silently moved.
#   _cwd_relocate   the OLD shell, which still knows the full path: move to the
#                   nearest ancestor that still exists. zshreload runs it before
#                   exec, so the reloaded shell lands as close to home as the
#                   filesystem still allows, instead of in ~.

_cwd_guard() {
    [[ -o interactive && $PWD != /* ]] || return 0
    print -ru2 "cwd-guard: the working directory no longer exists — moving to ~"
    cd -- "$HOME" 2>/dev/null || cd /
}

# Only acts when the cwd's inode no longer matches $PWD: the directory was
# deleted (or deleted and recreated, which getcwd cannot follow either).
_cwd_relocate() {
    [[ . -ef $PWD ]] && return 0
    local d=$PWD
    # The while below relies on :h reaching `/` in finite steps, which only an
    # absolute path guarantees; a "." PWD is _cwd_guard's case, not this one.
    [[ $d == /* ]] || d=$HOME
    while [[ $d != / && ! -d $d ]]; do d=${d:h}; done
    print -ru2 "cwd-guard: $PWD no longer exists — moving to $d"
    cd -- "$d" 2>/dev/null || cd -- "$HOME"
}

# Reload the shell. A function, not the old `alias zshreload="exec zsh -l"`, so
# it can put the cwd on solid ground first (docs/zsh.md, Lessons learned).
zshreload() {
    _cwd_relocate
    exec zsh -l
}

_cwd_guard

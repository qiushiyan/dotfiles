# Ctrl+D guard (last tmux pane)

Stops an accidental Ctrl+D from silently closing the **last pane of a tmux
window** — which also kills the window and whatever was running in it (e.g. a
Claude Code session). Lives in the Ctrl+D guard block in `zsh/.zshrc`.

## TL;DR

| Ctrl+D on… | Result |
|---|---|
| Empty line, **sole pane** of a tmux window | Refused — prints *"type 'exit' or prefix-x to close it"*, window stays |
| Empty line, multi-pane tmux window | Exits → closes just that pane |
| Empty line, no tmux | Exits the shell |
| Non-empty line | `delete-char-or-list` (completions), unchanged |

To deliberately close the last pane: type `exit` (or `prefix`-`x`). There is
**no single keystroke** that closes it — that's intentional, so a stray or
double Ctrl+D can't.

## Why it was needed

`prefix`-`x` confirms before killing a window; a bare Ctrl+D did not. In a
single-pane window it exits the shell → closes the pane → closes the window
instantly, with no confirmation and the session gone.

## Root cause (why the obvious fix didn't work)

Two traps, both about *which* `^D` binding is live at the prompt:

1. **Keymap / load order.** oh-my-zsh's `lib/key-bindings.zsh` runs `bindkey -e`
   unconditionally when sourced (`.zshrc` ~line 140), making the active (`main`)
   keymap **emacs** — overriding the `set -o vi` at the top. Any `^D` binding
   added *earlier* in `viins`/`vicmd` is in an inactive keymap and never fires.
2. **Raw byte vs CSI-u.** Ghostty normally sends Ctrl+D as the raw C0 byte
   (`^D`), and only sends the CSI-u form (`\e[100;5u`) when a TUI exits without
   popping the Kitty keyboard protocol. Binding only the CSI-u form (the old
   line-31 binding) missed the common case.

## Design — two layers, robust by construction

- **Floor: `setopt ignore_eof`.** An *option*, not a keybinding, so no keymap
  switch or plugin can clobber it. On its own it guarantees an empty-line EOF
  can never silently exit zsh. If the widget below is ever bypassed, the worst
  case is zsh's plain *"use 'exit' to exit"* — never a lost window.
- **UX: the `_guard_ctrl_d` widget, bound from a one-shot `precmd` hook.** The
  hook fires just before the first prompt — *after* oh-my-zsh, fzf,
  smart-suggestion, oh-my-posh — and binds `^D` **and** `\e[100;5u` in **all
  three keymaps** (`emacs`/`viins`/`vicmd`). So it lands wherever the active
  keymap ends up. It scopes the guard to the dangerous case and keeps normal
  Ctrl+D-to-exit everywhere else.

**No in-widget `read`.** An earlier version asked for a `y`/`n` confirm via
`read -k` inside the widget. It was fragile: the `zle -M` prompt painted a
keystroke late (the blocking `read` runs before ZLE's redraw), and the
confirm key leaked onto the command line (got run as a command). Refusing the
exit and pointing at `exit`/`prefix`-`x` needs no read at all.

## Extending / reverting

- **Same trap, other keys.** The Ctrl+C / Ctrl+L CSI-u bindings still sit in
  `viins`/`vicmd` only (see the block just below the guard). If they misbehave
  in emacs mode, move them into the `_guard_ctrl_d_bind` precmd hook and add the
  `emacs` keymap — same fix.
- **Verify it's live:** in a fresh shell, `bindkey '^D'` should print
  `"^D" _guard_ctrl_d`.
- **Revert:** `git checkout zsh/.zshrc` (and delete this file).

# Neovim diagnostics

How LSP and linter diagnostics are shown, navigated, and copied in this
dotfiles repo.

## TL;DR

| Trigger | What happens |
|---|---|
| `<leader>cd` | Current line's diagnostics in a float (press again to focus it, `q` to close) |
| `<leader>cy` | Yank current line's diagnostics to the clipboard, AI-friendly format |
| `<leader>xx` | Buffer diagnostics in Trouble |
| `<leader>xX` | Workspace diagnostics in Trouble |
| `]d` / `[d` | Jump to next / previous diagnostic |

`<leader>cd` and `]d`/`[d` are LazyVim/Neovim defaults. `<leader>cy` lives in
`config/keymaps.lua`; the Trouble keys in `plugins/diagnostics.lua` (paths
relative to `nvim/.config/nvim/lua/`). Trouble's lowercase/uppercase pair is
deliberately swapped from its default so that lowercase `xx` gets the common
case, the current buffer.

## One store, every language

Everything above reads from `vim.diagnostic`, Neovim's language-neutral
diagnostics store. Every LSP server and every linter publishes into that same
pipeline with the same fields — range, message, source, code — so these
bindings behave identically for TypeScript, Go, or anything else. Only the
cosmetics differ per server: `ts_ls` reports numeric codes (`2322`), gopls
string ones (`UndeclaredName`).

## The AI-friendly yank

`<leader>cy` formats the current line's diagnostics for pasting into an AI
chat:

```
src/app.ts:42 `user.name` (typescript 2339)
Property 'name' does not exist on type 'User'.
```

It needs no LSP round-trip: a diagnostic already carries the exact range it
covers, so the offending symbol is sliced straight out of the buffer. When a
piece isn't usable the header degrades gracefully — a multi-line, empty, or
over-long range drops the backticked symbol; a missing source/code drops the
parenthetical; the floor is `file:line` plus the message. Several diagnostics
on one line are yanked together, blank-line separated, each with its own
header.

## Why leader keys, not Ctrl-Shift

`config/keymaps.lua` also carries `<C-S-d>`/`<C-S-f>` bindings for the float
and code actions — they only work **outside tmux**. Terminals collapse
Ctrl-Shift chords to plain Ctrl unless the extended-keys protocol is enabled
end-to-end, and this tmux config doesn't enable it, so inside tmux `<C-S-d>`
arrives as `<C-d>` — half-page scroll, silently. Leader chords are ordinary
keystrokes and survive every layer; new bindings should prefer them.

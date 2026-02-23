## Window Tiling

- raycast

  - `capslock + b` browser
  - `capslock + t` terminal
  - `capslock + p` color picker
  - `option + hjkl` tile windows, `option + m`
  - `cmd + p` open dropdown
  - `cmd + enter` quick actions

- tmux
  - copy mode `prefix + [`

## General

- quit `<leader>qq` or `:qa`, save and quit `:x` or `ZZ`, quit buffer `Q`

- execute current buffer `<leader>cg`

- scroll

  - Small scroll `ctrl + u` and `ctrl + d` (this is remapped to `ctrl + u/d zz`)

- close all buffers `gb`, close current buffer `<leader>bd`

- further scroll `ctrl + f` and `ctrl + b`

- by a single line without cursor moving `ctrl + e` and `ctrl + y`

- hover `gh` or `shift + k`

- preview definition `gD`, go to preview window `<leader>l`

- move to start `0` and end of line `$`

- `V3j` select next 3 lines

- move lines

  - center `zz` or `zt`

  - move up or down `option + arrow`

- copy line `yy`, open yank history `gy`

- command history `<leader>:`

- whitelist word for spell check `zg`

- open link `gx`

- go to last insert and enter insert mode `gi`

- `tab` for command mode completion and `shift + tab` to navigate (or left or
  right arrow keys)

- show historical notifications: `<leader>snh`

## Session

- `<leader>qs` to restore session

## LazyGit

- `<leader>gg` open, `ac` add all and commit, `P` push

## Navigations

- `<leader>space` search files

- `<leader>ss` search symbols, for markdown this can be used as outlines

- `<leader>sr` search and replace

- jump function `]f` and `[f` (useful for jumping to component definition when
  in the middle of a react component)

- jump diagnostics `]d` and `[d`

- jump back and fort between last cursor position `ctrl + o` and `ctrl + i`

- switch windows `ctrl + w + w`

## Terminal

Toggle current terminal `ctrl + /`

- floating window `ctrl + backtick`

- on the bottom `<leader>th`

- on the right `<leader>Tv`

## File Operations

### File Explorer

- with `mini.files`

  - edit file systems like a buffer, add a new line, delete a new, etc.

  - `=` save

  - `,` reset

- with neo-tree

  - `a` or `n`: create file or directory

    - alternatively use a `mkdir.nvim` command `:save path/to/file.txt`

  - `m`: move file or directory
  - `d`: delete file or directory
  - `r`: rename file or directory
  - `/` search file
  - `shift + p` toggle preview

- delete current file with command `:!rm %`

- delete current buffer `<leader>bd`

- mark important files `<leader>m` (the `grapple` plugin)
  - navigate to marked files `M` or `<leader>M`

## Windows

- close all other windows `ctrl + w + o`

- close all other buffers `ctrl + b + o`

## Quickfix

- search `/` and find next occur `n` and previous `N`

- search and replace `<leader>sr`

- grep search `<leader>/` and add to quickfix list `ctrl + g`, use `[q`, `]q` or
  `cnext` and `cprevious` to navigate between them

## Marks

- `m<letter>` to create a mark

- backtick to list and go to marks

- delete all marks `:delm! | delm A-Z0-9`

## Code Actions and Refactoring

- hover `shift + k` and scroll in the popup window `ctrl +f`, `ctrl + b`

- see troubles pane `<leader>xx`

- show diagnostics for line `ctrl + shift + d`. next and prev diagnostics `]d`
  and `[d`

- code actions `ctrl + shift + f` or `<leader>ca`

- toggle comments `gcc`

- `gd` go to definition and jump back `ctrl+o`

- find references `gr`

- rename symbol `<leader>cr`

## Lsp

- check command `LspInfo` and `ConformInfo`

## Markdown

### Folds

- `zj` fold all level 1 headings, `zk` level 2 headings, `zl` level 3 headings

- `zR` unfold all

## Image test

![](../wall.jpg)

Reference:
https://levelup.gitconnected.com/render-images-inside-neovim-and-tmux-bd59381d0746

```bash
nvim --clean -c ":luafile test-imge.lua"
```

## AI

- Accept suggestion `option + enter`

## Misc

- inline math `option + 3` inside of backticks `1 + 2`

## General

- quit `<leader>qq` or `:qa`, save and quit `:x` or `ZZ`

- scroll

  - small scroll `ctrl + u` and `ctrl + d`

  - further scroll `ctrl + f` and `ctrl + b`

  - by a single line without cursor moving `ctrl + e` and `ctrl + y`

- hover `gh` or `shift + k`

- move to start `0` and end of line `$`

- move lines

  - center `zz` or `zt`

  - move up or down `option + arrow`

- whitelist word for spell check `zg`

- open link `gx`

- go to last insert and enter insert mode `gi`

- `tab` for command mode completion and `shift + tab` to navigate (or left or
  right arrow keys)

- show historical notifications: `<leader>snh`

## Navigations

- `<leader>space` search files

- `<leader>ss` search symbols, for markdown this can be used as outlines

- `<leader>sr` search and replace

- jump diagnostics `]d` and `[d`

- jump back and fort between last cursor position `ctrl + o` and `ctrl + i`

- switch windows `ctrl + w + w`

## Terminal

Toggle current terminal `ctrl + /`

- floating window `ctrl + backtick`

- on the bottom `<leader>th`

- on the right `<leader>Tv`

## File Operations

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

## Managing Buffers

- close all other buffers `ctrl + b + o`

## Windows

- close all other windows `ctrl + w + o`

## Text operations

- search `/` and find next occur `n` and previous `N`

- search and replace `<leader>sr`

## Code Actions and Refactoring

- hover `shift + k` and scroll in the popup window `ctrl +f`, `ctrl + b`

- see troubles pane `<leader>xx`

- show diagnostics for line `ctrl + shift + d`

- code actions `ctrl + shift + f` or `<leader>ca`

- toggle comments `gcc`

- `gd` go to definition and jump back `ctrl+o`

- find references `gr`

- rename symbol `<leader>cr`

## Lsp

- check command `LspInfo` and `ConformInfo`

## Copilot

- Accept suggestion `option + enter`

![](../night.webp)

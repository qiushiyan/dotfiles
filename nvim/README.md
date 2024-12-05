## General

- quit `<leader>qq` or `:qa`

```shell
#!/bin/bash
echo "hello world"
```

```r
plot(1:10)
```

```python
print("hello world")
```

- move lines

  - center `zz` or `zt`

  - move up or down `option + arrow`

- whitelist word for spell check `zg`

## Navigations

- `<leader>space` search files

- `<leader>ss` search symbols, for markdown this can be used as outlines

- `<leader>sr` search and replace

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

## Code Actions and Refactoring

- hover `shift + k` and scroll in the popup window `ctrl +f`, `ctrl + b`

- see troubles pane `<leader>xx`

- show diagnostics for line `ctrl + shift + d`

- code actions `ctrl + shift + f` or `<leader>ca`

- toggle comments `gcc`

- `gd` go to definition and jump back `ctrl+o`

- find references `gr`

- rename symbol `<leader>cr`

## Windows

- close all other windows `ctrl + w + o`

## Managing Buffers

- close all other buffers `ctrl + b + o`

## Text operations

- search `/` and find next occur `n` and previous `N`

- search and replace `<leader>sr`

## Copilot

- Accept suggestion `option + enter`

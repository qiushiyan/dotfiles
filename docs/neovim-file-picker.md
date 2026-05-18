# Neovim file picker

How file finding, grep, and the file explorer are wired in this dotfiles repo.

## TL;DR

| Trigger | Plugin | Purpose |
|---|---|---|
| `<leader><space>` | **fff.nvim** | Find files in cwd |
| `<leader>/` | **fff.nvim** | Live grep |
| `<leader>sw` | **fff.nvim** | Grep word under cursor |
| `<leader>sz` | **fff.nvim** | Fuzzy-mode grep |
| `<leader>,` | snacks.picker | Buffer switcher |
| `<leader>gl` | snacks.picker | Git log |
| `<M-k>` | snacks.picker | Keymap search |
| `<leader>e` | mini.files | File explorer (cwd) |
| `<leader>E` | mini.files | File explorer (file's dir) |

Three plugins, three jobs. No single tool owns everything.

## The three plugins, and why

- **fff.nvim** — the file/grep picker. Picked over snacks.picker for speed (Rust core, resident index, frecency ranking) and typo-resistant fuzzy matching. See `plugins/fff.lua`.
- **snacks.picker** — folke's picker, still installed because it has well-built buffer / git-log / keymap pickers and we have no reason to replace those. See `plugins/snacks.lua`.
- **mini.files** — the file explorer. Separate concern from the picker; fff doesn't do tree-style navigation. See `plugins/file-explorer.lua`.

`fzf-lua` is also installed as a LazyVim transitive default. Nothing in our config binds to it directly, but it stays loaded as a fallback that other LazyVim features might reach for.

## How keys resolve when plugins overlap

snacks.picker also ships a default `<leader><space>` binding. Lazy.nvim resolves duplicate `keys = { ... }` entries by spec order — files load alphabetically, so `snacks.lua` would normally win over `fff.lua`. Instead of relying on load order, the snacks keymap for `<leader><space>` and `<leader>/` was explicitly removed from `plugins/snacks.lua`. The other snacks keys stay.

If fff breaks and you need the old picker back fast: in `plugins/fff.lua`, set `enabled = false`, then re-add the two removed entries to `plugins/snacks.lua` (see the comment marker in that file pointing here).

## The `.env` problem and the `.ignore` workaround

fff respects `.gitignore` and there is **no config option to disable that** — the `ignore::WalkBuilder` flags are hardcoded in fff's Rust source. So `.env`, `.env.local`, and friends are invisible to the picker by default, which is annoying when you want to edit them.

The only mechanism fff (and ripgrep, and fd) understands for re-including a gitignored file is a sibling `.ignore` file with a negation rule:

```gitignore
!.env
!.env.*
```

`.ignore` is a convention from the `ignore` Rust crate and takes precedence over `.gitignore` in the picker. Git itself does not read `.ignore`.

To automate this, `plugins/fff.lua` defines `ensure_unignore_visible()`, which runs before each fff keymap. It finds the git repo root, and if no `.ignore` exists there, drops a templated one. Idempotent — won't touch an existing `.ignore`.

To keep these auto-generated files from leaking into commits, `.ignore` is listed in the global gitignore (`git/.config/git/ignore` in this repo, stowed to `~/.config/git/ignore` — git's default global excludes location). Git treats it as if it were gitignored in every repo.

**Adding more always-visible files:**

- For one project only: edit that project's `.ignore` directly (add another `!pattern` line)
- For all future projects: edit the template list inside `ensure_unignore_visible()` in `plugins/fff.lua`

**Stale `.ignore` files:** if you change the template, existing `.ignore` files in old projects don't auto-update (`ensure_unignore_visible` skips when the file exists). Delete the project's `.ignore` and reopen the picker to regenerate, or edit it by hand.

## Picker quirks worth knowing

- fff's background watcher reacts to `.ignore` and `.gitignore` changes (`background_watcher.rs`), so editing either triggers a rescan with no manual `:FFFScan` needed.
- fff's grep has three modes — `plain`, `regex`, `fuzzy` — cycled with `<S-Tab>` inside the picker. `<leader>sz` opens it pre-set to fuzzy-first for typo-resistant content search.
- Query language supports `git:modified`, glob patterns (`*.rs`), and `!` exclusions. Mix freely: `git:modified src/**/*.ts !test/ controller`.
- `:FFFHealth` is the first thing to run when something looks wrong. `:FFFOpenLog` shows the daemon log.

# Neovim image handling

How clipboard images get pasted into buffers and rendered on screen in this dotfiles repo.

## TL;DR

| Trigger | What happens |
|---|---|
| `<C-v>` (n/v/i) | Image on clipboard → img-clip paste to `/tmp`; otherwise normal text paste |
| `<leader>ii` | Explicit image paste to `/tmp/img-clip/`, absolute path, no filename prompt |
| `<leader>iI` | Image paste to the project's `img/` dir, relative path, prompts for a name |
| (automatic) | `![](path)` links in markdown render as a floating preview via snacks.image |

Pasting is **img-clip.nvim** (`plugins/img-clip.lua`); rendering is **snacks.image** (`plugins/snacks.lua`); the smart `<C-v>` lives in `config/keymaps.lua`.

## Why pasting needs a plugin at all

A terminal only transmits keystrokes and text — never image bytes. Apps that "paste images" (Claude Code's `[Image #1]`, img-clip here) all do the same trick: catch the keypress themselves and read the image straight off the OS clipboard. A buffer is plain text, so pasting an image can only ever mean *save the bytes to a file and insert its path*.

On macOS, img-clip reads the clipboard **exclusively through `pngpaste`** — no osascript fallback. It's in the Brewfile; without it every paste fails with "Could not get clipboard command" (`:checkhealth img-clip` when in doubt).

## Temp vs project destinations

Two paste flavors because there are two use cases with opposite lifetimes:

- **One-off** (default, `<C-v>` / `<leader>ii`) — e.g. showing a screenshot to Claude Code. Goes to `/tmp/img-clip/` with a timestamped name and an **absolute** path in the buffer, so any tool can read it from anywhere. Nothing to clean up in the project.
- **Keeper** (`<leader>iI`) — images that belong with a document. Goes to `img/` under the cwd with a **relative** path and a filename prompt.

This macOS has no `/etc/periodic` tmp-cleanup, so the img-clip spec purges its own temp dir: on plugin load it runs an async `find /tmp/img-clip -type f -mtime +3 -delete`. Reboots clear `/tmp` too. Consequence: a temp-pasted link goes dead after ~3 days — that's the point, but it's why documentation images must use `<leader>iI`.

## The image-aware `<C-v>`

`<C-v>` here has never been vim's visual block — `config/keymaps.lua` maps it (with `<C-c>`/`<C-x>`/`<C-z>`) to system-clipboard paste. The mapping is an expression map: it asks img-clip's `content_is_image()` (a `pngpaste` probe, a few ms) and resolves to `<Cmd>PasteImage<CR>` for an image, or the plain `"+p` text paste otherwise.

Quirk: some apps (Excel, rich-text editors) put *both* a text and an image representation on the clipboard — those paste as an image. Use `"+p` directly when you want the text.

## Rendering

snacks.image draws images via Ghostty's kitty-graphics support. Configured for a **floating preview** anchored to the editor's right edge (`doc.inline = false`, max 30×60) rather than inline replacement — the buffer text stays untouched.

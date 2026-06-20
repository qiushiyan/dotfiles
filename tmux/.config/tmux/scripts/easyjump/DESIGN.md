# easyjump (flash-style jump) — design

A flash.nvim-style jump for tmux copy mode: press a key, type characters to
search, and every match on screen gets a label live as you type — press the
label to land the copy-mode cursor there (and start a selection for copy).

This is a **vendored fork** of [`roy2220/easyjump.tmux`](https://github.com/roy2220/easyjump.tmux),
not the upstream plugin. `UPSTREAM-README.md` is the original readme for
reference.

## Why a fork (and why it lives here)

Upstream is a solid engine but has two defects for a flash-like feel:

1. **Fixed 2-character search** — `get_key()` read exactly two chars and stopped;
   everything after was label selection. No incremental narrowing.
2. **Full-screen red repaint** — the overlay recoloured *all* text red (captured
   without colours) and drew dim labels: the inverse of flash, which dims the
   backdrop and makes labels pop.

We keep upstream's hard-won plumbing and replace only those two layers. It lives
in `scripts/easyjump/` (tracked + stowed) rather than `~/.config/tmux/plugins/`
(gitignored, blown away by `prefix U`), so our changes survive and travel.

## Binding

`tmux.conf` binds it directly (no TPM `@plugin`):

```tmux
bind-key s run-shell -b "$HOME/.config/tmux/scripts/easyjump/easyjump.sh"
bind-key -T copy-mode-vi C-s run-shell -b "$HOME/.config/tmux/scripts/easyjump/easyjump.sh"
```

`easyjump.sh` resolves `python3` robustly (tmux's `run-shell` PATH can be thin)
and logs stderr to `$TMPDIR/tmux-easyjump.log`.

## How it works

- **Capture** (`Screen`): reads pane geometry, cursor, copy-mode/selection state
  via `display-message`, and the visible text via `capture-pane`. Handles
  scroll position, the alternate screen, and CJK/wide-char widths.
- **Overlay** (`Screen.overlay`/`draw`): enters the alternate screen (tmux
  default) so we can repaint freely and restore cleanly on exit. `draw()`
  repaints on *every* keystroke — this is the change that makes the search
  incremental. (In alternate-screen mode `_update` doesn't touch
  `scroll_position`, so repeated draws are safe.)
- **Incremental loop** (`interactive`): the flash model. Type characters to
  narrow; a label key jumps to that match; `Enter` jumps to the nearest
  (unlabelled) match; `Escape` cancels. With autojump on (`--autojump`, default
  on), a query that leaves exactly one match jumps immediately — but only on
  forward typing, so backspacing down to one match still waits. Keys are read as
  tmux key *names* (`command-prompt -k`) so `Enter`/`Escape`/`BSpace`/`Space`
  are distinguishable from literal characters.
- **Label algorithm** (`continuation_chars` + `generate_labels` +
  `assign_labels`): flash's load-bearing rule — *a label is never a character
  that could continue the search.* We collect the character after each match and
  exclude those from the label alphabet, so each keypress is unambiguous (extend
  the search vs. pick a label). Labels are **single-character only**: matches
  beyond the alphabet go unlabelled and you narrow by typing (flash's
  philosophy) — this keeps a keypress unambiguous and stops a label from
  overdrawing an adjacent match. Two flash refinements: nearest matches get
  labels first (`rank_positions`), and a match **reuses its previous label**
  across keystrokes when still available, so labels don't reshuffle as you
  narrow. **Every** match is labelled, including the nearest (flash's
  `label.current`): the nearest additionally carries the distinct "current"
  highlight and `Enter` is a shortcut to it — but it still has its own label, so
  a match you can see always has a key to jump to it.
- **Render** (`Screen.render`): a calm grey **backdrop**, the typed substring
  **highlighted**, the nearest match (the `Enter` target) in a **distinct**
  colour, and a **label** overlaid on each labelled match.
- **Jump** (`jump_to_pos`, upstream): after the overlay tears down, drive the
  copy-mode cursor to the target with `send-keys -X cursor-*`, then
  `begin-selection`.

## Colours

Four ANSI attribute strings near the top of `easyjump.py` (`LABEL_ATTRS`,
`TEXT_ATTRS` = backdrop, `MATCH_ATTRS`, `CURRENT_ATTRS`). They use explicit
fg+bg so they read on both the light and dark terminal themes. Tune there, or
pass `--label-attrs` / `--text-attrs` / `--match-attrs` / `--current-attrs` from
the launcher.

## Known limitations (v1)

- **Backdrop loses syntax colour.** v1 flattens the backdrop to one grey
  (chosen for simplicity). A colour-preserving backdrop (parse `capture-pane -e`
  SGR codes, dim each foreground) is the planned stretch — see git history /
  conversation.
- **Key-name detection** for `Enter`/`Escape`/`BSpace` depends on what
  `command-prompt -k` reports per terminal; the loop accepts a few aliases
  (`C-m`, `C-c`/`C-g`, `C-h`/`DC`/`C-?`). Adjust in `interactive` if a key
  misbehaves.
- **Far matches go unlabelled.** With more matches than label characters
  (~36 minus continuations), only the nearest ones get labels; reach the rest by
  typing more of the search. (No multi-char labels by design — see above.)
- **Alternate-screen edge.** The non-alternate path (tmux `alternate-screen
  off`) is exercised rarely; copy-mode scroll compensation is applied in
  `overlay()`'s teardown once per logical draw so per-keystroke repaints don't
  compound it, but this path is hard to test without that non-default option.

## Updating from upstream

The engine (capture, copy-mode cursor driving, width math) is largely upstream.
To pull fixes, diff against a fresh clone of `roy2220/easyjump.tmux` and
re-apply our changes. We also removed upstream's mouse mode (`Mode`,
`_mouse_jump_to_pos`, `--mode`/`--print-command-only`) and the `--key`/
`--cursor-pos` presets, since the launcher only drives copy mode. Our additions
live in: `parse_args` (extra `--*-attrs`, `--autojump`), `Screen.overlay`/
`draw`/`render`/`raw`, `read_key`/`key_to_char`/`continuation_chars`,
`generate_labels`, `rank_positions`, `assign_labels` (reuse + skip-current), and
`interactive`/`main`.

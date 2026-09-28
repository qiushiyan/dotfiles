# easyjump (flash-style jump) — design

A flash.nvim-style jump for tmux copy mode: press a key, type characters to
search, and every match on screen gets a label live as you type — press the
label to land the copy-mode cursor there (and start a selection for copy).

This is a **vendored fork** of
[`roy2220/easyjump.tmux`](https://github.com/roy2220/easyjump.tmux), not the
upstream plugin. Git preserves the imported source; this file records the delta
that must survive an upstream refresh. `tmux.conf` binds `easyjump.sh` directly
(`prefix s`, and `C-s` in copy mode); the launcher logs stderr to
`$TMPDIR/tmux-easyjump.log`.

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

## Label rules

These carry the flash feel; the comments in `easyjump.py` hold their mechanics.

- **A label is never a character that could continue the search**, so every
  keypress either extends the query or picks a label, never both.
- **Labels are single characters.** Matches beyond the alphabet go unlabelled
  and you narrow by typing; this also stops a label overdrawing an adjacent
  match.
- **A match keeps its label across keystrokes** while that label is still
  free, so labels don't reshuffle as you narrow. Nearest matches are labelled
  first, and every match gets a label — the nearest too, which `Enter` also
  reaches.

Colours are explicit fg+bg attribute strings at the top of `easyjump.py`,
readable on light and dark themes.

## Known limitations (v1)

- **Backdrop loses syntax colour.** The overlay intentionally flattens the
  backdrop to one grey. A colour-preserving version is tracked in
  `../../roadmap.md`.
- **Key-name detection** for `Enter`/`Escape`/`BSpace` depends on what
  `command-prompt -k` reports per terminal; the loop accepts a few aliases
  (`C-m`, `C-c`/`C-g`, `C-h`/`DC`/`C-?`). Adjust in `interactive` if a key
  misbehaves.
- **Far matches go unlabelled.** With more matches than label characters
  (~36 minus continuations), only the nearest ones get labels; reach the rest by
  typing more of the search.
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
`generate_labels`, `rank_positions`, `assign_labels` (reuse + label-current), and
`interactive`/`main`.

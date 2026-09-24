# tmux-popupfix: why tmux comes from a local tap

**Status: temporary carry.** Homebrew's `tmux` is replaced by
`qiushiyan/local/tmux-popupfix` — stock tmux 3.7c with jemalloc plus one
popup overlay fix. Retire it (see below) once an upstream release after 3.7c
fixes popups under `status-position top`. Upstream's 3.8 change log names broad
redraw fixes around status lines, popups, and floating panes, but not this exact coordinate
case; the reproduction harness remains the retirement gate.

## Why jemalloc is required

On macOS Tahoe / Apple Silicon, entering copy mode can abort in
`window_copy_clone_screen → screen_reinit → grid_clear_lines → grid_free_line`
with an invalid-memory free. Upstream suspects macOS `calloc` returning stale
data and uses jemalloc to avoid it in 3.7c
([issue #5385](https://github.com/tmux/tmux/issues/5385),
[release fix](https://github.com/tmux/tmux/commit/e476c1230b958df0cb12977517d24b3dc931375b)).
The formula explicitly depends on jemalloc and enables it at configure time.
Keep both when updating; changing terminal settings does not supply this fix.

The popup patch remains necessary: upstream `screen-redraw.c` is identical
in 3.7b and 3.7c. Stock 3.7c reproduces the overwritten popup border; the
patched build preserves it and the pane divider below it.

## The bug it fixes

With the status bar at the **top** (this setup: `status 2` +
`status-position top`), any `display-popup` over a busy pane — Claude Code
streaming, `htop`, anything that redraws — gets its **top N rows overwritten**
by the pane behind it (N = status height), while the N rows *below* the popup
stop being drawn (pane dividers vanish there). The rename-pane popup
(`prefix M`) losing its title border to Claude's output is this bug.

Root cause, in tmux `screen-redraw.c`: popups register their overlay region in
**tty coordinates** (row 0 = top of the terminal, including the status area),
but four drawing paths ask "is this cell under the popup?" using **window
coordinates** (row 0 = first row *below* a top status bar) while drawing at tty
coordinates. The protected region therefore lands `statuslines` rows below the
popup: the popup's top rows are unprotected (overwritten) and the rows under it
are wrongly protected (never redrawn). With the default bottom status the two
coordinate systems coincide, which is why upstream never noticed — their
regression test for the related fix (tmux PR #4920, commit `d71d38a`, already
in 3.7b) uses a bottom status bar and passes despite this.

The patch fixes the y passed to the overlay check in the four paths:
`screen_redraw_draw_pane` (pane content), `screen_redraw_draw_pane_status`
(per-pane border titles), `screen_redraw_draw_borders_cell` (pane dividers —
the missing-`│` artifact), and `screen_redraw_draw_pane_scrollbar`.

Two related config changes live in `tmux/.config/tmux/tmux.conf` and are
independent of the patch: the `sync` terminal feature for Ghostty (atomic
redraws — tmux can't autodetect it because Ghostty ships terminfo inside its
app bundle) and an explicit `popup-style`/`popup-border-style` background
(default-bg cells are translucent under Ghostty's `background-opacity`).

## Where things live

- **Formula + embedded patch**: `/opt/homebrew/Library/Taps/qiushiyan/homebrew-local/Formula/tmux-popupfix.rb`
  (the tap is a local git repo with no remote).
- **Tracked copy**: `docs/tmux-popupfix.rb` in this repo — the tap can be
  recreated from it (`brew tap-new qiushiyan/local`, copy the file into its
  `Formula/`, `brew install qiushiyan/local/tmux-popupfix`). MIGRATION note:
  `make brew` needs this done first, since the tap has no remote to fetch.
- Stock Homebrew `tmux` is **unlinked**. Switching to it with
  `brew unlink tmux-popupfix && brew link tmux` drops the popup correction;
  retain it as a comparison build until the patch can be retired.

## Upgrading and activating

Update the tracked formula, then copy it to the local tap's `Formula/` and run
`brew upgrade qiushiyan/local/tmux-popupfix`. Keep the previous keg until the
old server has exited (`HOMEBREW_NO_INSTALL_CLEANUP=1` during the upgrade).
Commit the tracked copy and local tap change in their respective repositories.

Check the installed binary and its allocator:

```bash
tmux -V
otool -L "$(brew --prefix tmux-popupfix)/bin/tmux"
tmux display-message -p 'server=#{version} pid=#{pid}'
```

The binary must report 3.7c or newer and list `libjemalloc`. The server can
still report an older version: installing or relinking does not replace a
running server. Finish running jobs before ending the old server and starting
a new one. A resurrect snapshot preserves layout and selected commands, not
live process state. After restarting, repeat the server-version check.

## Verifying / reproducing

Run the regression check against a known-broken stock 3.7b/3.7c binary and
the candidate build:

```bash
python3 tmux/.config/tmux/scripts/tests/test-popup-overlay.py \
  --stock "$(brew --prefix tmux)/bin/tmux" \
  --candidate "$(brew --prefix tmux-popupfix)/bin/tmux"
```

It uses private sockets, a temporary home and minimal config, and `/bin/sh`
panes. It requires stock to reproduce the broken top border, checks the
candidate's border and lower divider across redraws, and enters/exits copy
mode. This verifies popup behavior, not the rare allocator crash's absence.
For patch retirement, pass the future stock release as `--candidate` and keep
a known-broken binary as `--stock`.

Nested-tmux harness, no screenshots needed: run a scratch server with
`status 2` + `status-position top`, a side-by-side split with
`while true; do seq 1 6; sleep 0.05; done` in one pane, open
`display-popup -E 'sleep 100'`, and attach a client from a pane of another
tmux server (`env -u TMUX tmux -L scratch attach`) — then `capture-pane` on
that outer pane shows exactly what the inner server drew, popup included.
Broken: popup's top border row is replaced by stream output. Fixed: popup
intact, dividers present below it.

## Retiring the patch

The office mini carries the same tap and build (`docs/qiushi-mini.md`
§ Toolchain); retire it there in the same pass.

When a tmux release after 3.7c lands (check its CHANGES for a popup/overlay
coordinate fix; if unclear, install and rerun the harness above):

1. `brew uninstall tmux-popupfix && brew install tmux`
2. Brewfile: restore `brew "tmux"`, drop the `qiushiyan/local` tap line
3. Delete this file and `docs/tmux-popupfix.rb`; `brew untap qiushiyan/local`

If reporting the exact case, use the repro above against master with
`status-position top` and reference PR #4920, whose fix this extends.

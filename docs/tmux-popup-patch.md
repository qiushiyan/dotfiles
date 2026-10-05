# tmux-popupfix: why tmux comes from a local tap

**Status: temporary carry.** Homebrew's `tmux` is replaced by
`qiushiyan/local/tmux-popupfix` — stock tmux 3.7c with jemalloc plus a patch
to `screen-redraw.c` for the defects below. Retire it (see below) once an
upstream release after 3.7c passes the reproduction harness. Upstream's 3.8
change log names broad redraw fixes around status lines, popups, and floating
panes, and its branch rewrites pane status drawing, but neither names these
exact cases; the harness remains the retirement gate.

## What it fixes

### Popups overwritten under a top status bar

With the status bar at the **top** (this setup: `status 2` +
`status-position top`), any `display-popup` over a busy pane — Claude Code
streaming, `htop`, anything that redraws — gets its **top N rows overwritten**
by the pane behind it (N = status height), while the N rows *below* the popup
stop being drawn (pane dividers vanish there). The rename-pane popup
(`prefix M`) losing its title border to Claude's output is this bug.

Root cause, in tmux `screen-redraw.c`: popups register their overlay region in
tty coordinates, but the drawing paths check it in window coordinates, so with
a top status bar the protected region lands `statuslines` rows too low; the
patched functions are listed in the header of `docs/tmux-popupfix.rb`. With the
default bottom status the two coordinate systems coincide, which is why
upstream's regression test for the related fix (tmux PR #4920, commit
`d71d38a`, already in 3.7b) passes despite this. Upstream `screen-redraw.c`
is identical in 3.7b and 3.7c: stock 3.7c reproduces the overwritten popup
border, and the patched build preserves it and the pane divider below it.

Two related config changes live in `tmux/.config/tmux/tmux.conf` and are
independent of the patch: the `sync` terminal feature for Ghostty (atomic
redraws — tmux can't autodetect it because Ghostty ships terminfo inside its
app bundle) and an explicit `popup-style`/`popup-border-style` background
(default-bg cells are translucent under Ghostty's `background-opacity`).

### Redraw stall when a narrower client draws pane status

With `pane-border-status` on, as `tmux-agent-status.sh` sets it on every
window holding an agent pane, a client narrower than the window it shows makes
stock 3.7c burn 5–10 s of CPU per redraw. The server answers nothing
meanwhile, so every key press on every client waits. The case arises whenever
clients of different sizes share a session: the mini's desk terminal and an
ssh client from the laptop are enough.

Root cause, in `screen_redraw_draw_pane_status`: for a status line cut off at
the client's right edge, the visible width is taken from the status line's
length instead of the client's width. It underflows when the line starts
further right in the view than it is long, and `tty_draw_line` walks ~2^32
cells. Upstream tracks it as
[issue #5664](https://github.com/tmux/tmux/issues/5664), reported against 3.7c
on macOS and Linux.

A server on an unpatched binary escapes it by config alone:
`window-size smallest` (no client sees a cut-off window), a single attached
client (`tmux attach -d`), or `pane-border-status off`.

## Where things live

- **Formula + embedded patch**: `/opt/homebrew/Library/Taps/qiushiyan/homebrew-local/Formula/tmux-popupfix.rb`
  (the tap is a local git repo with no remote).
- **Tracked copy**: `docs/tmux-popupfix.rb`. Recreate the tap from it
  (`brew tap-new qiushiyan/local`, copy the file into its `Formula/`,
  `brew install qiushiyan/local/tmux-popupfix`); on a new machine `make brew`
  needs this first, since the tap has no remote.
- **jemalloc stays in the formula**, as a dependency and at configure time,
  matching stock Homebrew `tmux`: without it, entering copy mode on macOS
  Tahoe / Apple Silicon can abort with an invalid-memory free
  ([issue #5385](https://github.com/tmux/tmux/issues/5385)).
- Stock Homebrew `tmux` is **unlinked**. Switching to it with
  `brew unlink tmux-popupfix && brew link tmux` drops the patch;
  retain it as a comparison build until the patch can be retired.

## Upgrading and activating

Update the tracked formula, then copy it to the local tap's `Formula/` and run
`brew upgrade qiushiyan/local/tmux-popupfix`. A patch change at the same tmux
version needs the formula's `revision` raised, or brew sees nothing to upgrade
and builds no new keg. Keep the previous keg until the
old server has exited (`HOMEBREW_NO_INSTALL_CLEANUP=1` during the upgrade).
Commit the tracked copy and local tap change in their respective repositories.

Check the installed binary and its allocator:

```bash
tmux -V
otool -L "$(brew --prefix tmux-popupfix)/bin/tmux"
tmux display-message -p 'server=#{version} pid=#{pid}'
lsof -p "$(tmux display-message -p '#{pid}')" | grep bin/tmux
```

The binary must report 3.7c or newer and list `libjemalloc`. The server can
still report an older version: installing or relinking does not replace a
running server. Finish running jobs before ending the old server and starting
a new one. A resurrect snapshot preserves layout and selected commands, not
live process state. After restarting, repeat the server checks: the version
reads the same across a `revision` bump, so the `lsof` line's keg path is what
shows which build the server runs.

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
mode. It then attaches a client narrower than a window with pane status on:
stock must stall, and the candidate must answer within a second with both
status lines drawn. This verifies redraw behavior, not the rare allocator
crash's absence.
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

When a tmux release after 3.7c lands, install it and rerun the harness above;
its CHANGES may not name either case. Once it passes:

1. `brew uninstall tmux-popupfix && brew install tmux`
2. Brewfile: restore `brew "tmux"`, drop the `qiushiyan/local` tap line
3. Delete this file and `docs/tmux-popupfix.rb`; `brew untap qiushiyan/local`

If reporting the popup case, use the repro above against master with
`status-position top` and reference PR #4920, whose fix this extends.

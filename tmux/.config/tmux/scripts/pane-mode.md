# Pane mode — design

Satellite of `float-pane.md`. Read this when changing the `prefix p` key table,
directional push, the undo journal, or cross-window moves (hold, put, pick).
Shared filtering of native floating panes remains in `float-pane.md`; helpers
the pane scripts share live in `lib/tmux-common.sh`.

## Push

```text
h/j/k/l + neighbour → trade places
h/j/k/l + open edge → move to that wall
already spans edge  → no-op
```

tmux directional targets wrap: `{left-of}` from the leftmost pane resolves to
the rightmost pane. `#{pane_at_<dir>}` is therefore the gate between neighbour
and wall; a bare directional `swap-pane` is incorrect.

Relocation targets an explicit sibling pane. A window target resolves to that
window's active pane, which may be the source and fail with `source and target
panes must be different`.

## Undo journal

`select-layout -o` remembers geometry, not pane identity, so it cannot reverse a
swap. `u` instead pops a per-window journal entry:

```text
(ordered pane ids, layout)
```

The journal covers pushes only. Cross-window moves (put, pick) and break can
destroy the window holding the record and would need a different transaction
model. They invalidate the journals of both windows instead: a record whose
pane set no longer matches would otherwise be refused and kept forever.

Validate the pane-id set before consuming an entry. A push changes neither pane
count nor membership; a later split or exit makes replay unsafe, so undo refuses
and retains the record.

Push scripts use foreground `run-shell`. The key table re-enters immediately;
background repeats would race the journal's read-modify-write and lose entries.

## Cross-window moves: hold, put, pick

```text
g → hold this pane (@pane_hold), leave the mode → walk with window keys
p → put the held pane here as the full-height right column, stay in the mode
G → release the hold
w → pick: popup of this session's other windows, Enter moves this pane there
```

The hold is one pane id in a private global option, not tmux's mark: the mark
is replaced by any `select-pane -m` from any client, and its presence flips
`move-pane`'s default source. `move-pane` must still receive `-s`: without an
explicit source and with a mark present, tmux moves the marked pane instead.

`put` re-validates the hold, whatever its age. A gone or native-floated pane
clears it. A pane floated by `prefix z` keeps it, so closing the float makes it
usable again.

`pick` captures its source pane as an argument before the popup opens and never
reads the hold: another client may replace the hold while the popup is up. It
re-enters pane mode itself on every exit path. Its client name goes through
`live_client` (`float-pane.md`, "Traps") for both the popup and the re-entry.
The popup is a transient dialog, so it keeps the global rounded frame.

## Verification

Exercise neighbour swaps, every wall, repeated pushes, stale undo after a split,
hold/put/pick across windows, and a native floating pane. The pane-control suite
owns the executable cases:

```text
tmux/.config/tmux/scripts/tests/test-pane-control.sh
```

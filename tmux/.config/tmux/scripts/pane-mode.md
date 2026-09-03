# Pane mode — design

Satellite of `float-pane.md`. Read this when changing the `prefix p` key table,
directional push, undo journal, or mark-and-move behavior. Shared filtering of
native floating panes remains in `float-pane.md`.

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

The journal covers pushes only. Cross-window `m`/`M` moves can destroy the
window holding the record and require a different transaction model.

Validate the pane-id set before consuming an entry. A push changes neither pane
count nor membership; a later split or exit makes replay unsafe, so undo refuses
and retains the record.

Push scripts use foreground `run-shell`. The key table re-enters immediately;
background repeats would race the journal's read-modify-write and lose entries.

## Mark and move

```text
m → mark current pane
M → re-resolve mark → move current pane to it
```

The mark is server-global and may change between keys. `join-pane`/`move-pane`
must receive `-s`: without an explicit source, tmux treats the marked pane as
the source and performs the opposite move.

## Verification

Exercise neighbour swaps, every wall, repeated pushes, stale undo after a split,
cross-window mark/move, and a native floating pane. The pane-control suite owns
the executable cases:

```text
tmux/.config/tmux/scripts/tests/test-pane-control.sh
```

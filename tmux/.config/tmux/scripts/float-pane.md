# Floating zoom & pane mode — design notes

Two features, one control plane for moving panes around:

- **`prefix z`** — maximize the current pane into a *floating* overlay instead of
  tmux's all-or-nothing zoom, so the rest of the window stays visible and live
  behind it. `tmux-float-pane.sh`.
- **`prefix p`** — a sticky "pane mode" key table holding every pane-moving verb
  behind one key. `tmux-pane-relocate.sh` + the `panes` table in `tmux.conf`.

Requires **tmux 3.7b+**. Tests: `scripts/tests/test-pane-control.sh` (44 cases,
runs on throwaway sockets — it never touches a live server).

---

## Why the float is built this way

tmux cannot display an existing pane inside a popup, and tmux 3.7's native
floating panes explicitly **cannot convert between floating and tiled** yet —
the 3.6b→3.7 CHANGES lists that as missing, and it is tracked in
[tmux#5135](https://github.com/tmux/tmux/issues/5135) for 3.8. The zoom/float
interaction is itself an open upstream question
([tmux#5258](https://github.com/tmux/tmux/issues/5258)).

So the pane is genuinely relocated: broken out into a detached **holder
session**, which a **container** (a popup running a nested `attach`) displays.
The pane keeps running the whole time — only its geometry changes.

This is the same mechanism `tmux-floax` and the various "floating scratch
terminal" recipes use (dedicated session + popup + attach/detach as the
toggle). What is new here is pointing it at the *current* pane.

**Panes behind the container keep redrawing.** The man page's "Panes are not
updated while a popup is present" is stale — CHANGES has *"Do not freeze output
in panes when a popup is open, let them continue to redraw"*, and a ticker
behind a popup was measured rendering 83 updates live. Only the region the
container physically covers is clipped. That is the whole point of this over
`resize-pane -Z`.

### The container seam

`open_container()` is the only function that knows how the holder gets on
screen. When tmux can adopt an existing pane into a native floating pane,
swapping that function's body for `new-pane` is the entire migration — and a
native float is non-modal, so the background would become interactive, not
merely visible.

## Restore is optimistic, not a replay

`select-layout <string>` restores **geometry but not identity**: the layout
string addresses panes by index order, so a naive break/join round trip on
`%0 %1 %2` comes back as `%0 %2 %1` with the geometry "right" and the wrong
panes in the slots. Restore therefore permutes panes back to the recorded order
with `swap-pane` **first**, then applies the layout.

And it only does that if the source window still looks like what we left. Two
snapshots are recorded: the original, and the *expected post-break* state.

| Source window on restore | What happens |
|---|---|
| matches the expected snapshot | exact restore — permute to recorded order, then apply the saved layout |
| same panes, different geometry | another client rearranged it; restore identity order only and let their layout stand |
| panes added or removed | degraded — the pane comes home, live layout untouched |
| window gone, session alive | rebuilt near the recorded index/name |
| session gone | holder is renamed into a visible `recovered-*` session |

The pane is **never** killed to satisfy cleanup.

## State lives on the pane

All float metadata is in pane-local user options (`@fl_*`), so it travels with
the pane and two panes can be floated at once without colliding. The older
`prefix P` / rename-pane popups stash context in *global* env vars, which races
when two clients act at once — nothing here does that.

## Failure paths

`restore` is idempotent, and the container's own shell calls it on every
ordinary exit (`prefix z`, `prefix d`, the client being killed). The backstop
for a SIGKILL'd container is a **sweep on `client-attached`**.

Two things the sweep must get right, both found by tests:

- **A live float is not stranded.** The container attaching to the holder *is* a
  `client-attached` event; a sweep that ignored this restored the pane the
  instant the float opened, silently undoing the feature. Holders with an
  attached client are skipped.
- **A grace window** covers the gap between `break-pane` and the container's
  attach, where a holder legitimately has no client yet. Because the sweep only
  runs on attach, it re-checks once after the grace rather than leaving a
  too-young holder unexamined until the next attach.

`prepare-save` uses the opposite predicate — it normalises *every* float,
live ones included.

## Why resurrect saves go through a wrapper

A snapshot taken mid-float is unrecoverable: it records the source window
without the pane, plus a `_float_*` session holding it, and resurrect's format
carries no pane user options to relink them (pane ids do not survive a restart
either). Continuum saves every 15 minutes, so any float outliving a tick is
exposed.

There is no pre-save hook — resurrect only fires `post-save-layout` and
`post-save-all`, both too late. But continuum does not call resurrect directly:
it reads `@resurrect-save-script-path` and execs it. Pointing that at
`tmux-resurrect-save.sh` covers the timer; `prefix C-s` is rebound separately
because resurrect binds it straight to its own `save.sh`, bypassing the option.

Both re-applied **after tpm**, since `resurrect.tmux` sets the option with `-gq`
on every load.

## The float's key surface

Inside the float the prefix drives a nested client, so without care every
binding in this config fires against the holder — including `x`/`X`/`Q` (kill),
`c`/`N`/`|` (create), `W` (worktrees) and `T`/`C-f` (session switches).

The holder gets **both** halves of the restriction:

- `key-table float-root` — the client's root table inside the float
- `prefix None` / `prefix2 None` — **required**. tmux intercepts the prefix key
  *itself* and jumps straight to the built-in `prefix` table, bypassing a custom
  root table entirely. Verified: with the prefix left set, `#{client_key_table}`
  read `prefix`, not `float-prefix`, and the full surface was live. With no
  prefix to intercept, the `C-b`/`C-a` bindings in `float-root` fire and
  `prefix z` still means "close the float".

Keys unbound in a custom root table pass through to the pane, so typing in the
floated app is unaffected — the standard nested-tmux recipe.

## Pane mode: one rule for h/j/k/l

**Push the pane that way. If something is there, trade places. If nothing is
there, become the wall.**

The edge guard is load-bearing, not a nicety: tmux's directional targets
**wrap**, so `{left-of}` from the leftmost pane resolves to the *rightmost* one
(verified). An unguarded `swap-pane -t '{left-of}'` — what `tmux-tilish` does —
silently swaps with the pane on the opposite side. `#{pane_at_<dir>}`
distinguishes "there is a neighbour" from "I am against that wall".

A pane that is already the full-span pane on the requested edge no-ops, since
re-running the relocation churns pane order for no visible change.

### Undo is a journal, not `select-layout -o`

`-o` undoes the last *geometry* change, but a swap changes pane **identity** at
identical geometry, so it cannot reverse a push — and replaying a layout string
has the same identity blindness. `u` pops a per-window journal of
`(ordered pane ids, layout)` pairs recorded before every mutation.

### Mark and move

`m` marks, `M` moves the current pane to the mark. The mark is server-global and
can be replaced between the two, so it is re-resolved immediately before use.

`-s` is **mandatory** on the move: with `-s` omitted and a mark present,
`join-pane`/`move-pane` use *the marked pane as the source* (man tmux), i.e.
they perform the exact opposite move.

## Native floating panes are filtered everywhere

`prefix *` (stock, 3.7) creates a native floating pane. Those are counted by
`#{window_panes}` and embedded in `#{window_layout}` as a trailing `<...>`
segment, so every pane list, count, and comparison in both scripts filters on
`#{pane_floating_flag}`. Otherwise a stray float would corrupt a snapshot or let
the float logic break out the last real tiled pane. Pane mode refuses to move
them — tmux says `cannot swap floating panes`.

## Gotchas worth not re-learning

- **`show-option -t "=name"` reads back empty**, with rc=0. The `=` exact-match
  form is for a target-*session* (`has-session`, `kill-session`,
  `attach-session` take it); `show-option`'s target is a target-*pane*. Using it
  made every holder look unmarked, so the sweep found nothing.
- **`IFS= read -r a b c`** disables splitting entirely — the whole line lands in
  `a`. Use `IFS=' '`.
- **`display-popup` blocks** its issuing command until dismissed, which is why
  the key binding calls the script with `run-shell -b`.
- **`run-shell` expands `#{...}`; `display-popup` does not** in its command
  argument. That is why the pane id travels as a `run-shell` argument here
  instead of through a global env var.
- **`-t <window>` on join/move-pane resolves to that window's *active* pane**,
  which is usually the source itself → `source and target panes must be
  different`. Always target an explicit sibling.
- **3.7 needs `fill=` in `message-style`** or the message bar only paints behind
  its text (stock default became `bg=yellow,fg=black,fill=yellow`).
- **`unbind p` ran after `bind-key p`** in `tmux.conf` and silently killed pane
  mode. Order matters in a single-pass config.

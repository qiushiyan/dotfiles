# Floating zoom & pane mode — design notes

One control plane for moving panes around, in three parts:

- **`prefix z`** — maximize the current pane into a *floating* overlay instead of
  tmux's all-or-nothing zoom, so the rest of the window stays visible and live
  behind it. `tmux-float-pane.sh`.
- **`prefix Z`** — an *ephemeral* scratch shell in a popup; see "The scratch
  popup".
- **`prefix p`** — a sticky "pane mode" key table holding every pane-moving verb
  behind one key. `tmux-pane-relocate.sh` + the `panes` table in `tmux.conf`;
  its push, undo, and hold/put/pick model lives in `pane-mode.md`.

Requires **tmux 3.7b**. Tests: `scripts/tests/test-pane-control.sh` (the
isolation rules a new case must honour are in `docs/testing.md`). Shared
helpers: `scripts/lib/tmux-common.sh`. The comments in `tmux-float-pane.sh` own
the mechanism — its verbs, the `@fl_*` state, the claim protocol and the sweep;
this file keeps the decisions behind them.

---

## The float

### Why the pane is relocated

tmux cannot display an existing pane inside a popup, and tmux 3.7's native
floating panes **cannot convert between floating and tiled** (tracked in
[tmux#5135](https://github.com/tmux/tmux/issues/5135) for 3.8). So the pane is
genuinely relocated: broken out into a detached **holder session**, which a
**container** (a popup running a nested `attach`) displays. The pane keeps
running and panes behind the container keep redrawing, which is the whole point
over `resize-pane -Z`.

### The container adapter

Four functions know the holder is shown by a popup running a nested attach:
`container_restrict_keys` / `container_release_keys`, `open_container`,
`container_dismiss`, and the `container` verb. Everything else is
container-agnostic, so migrating to a native floating pane means rewriting those
four. They are also the only part a second feature should reuse: the holder
state machine exists to relocate a tiled pane and restore a source layout, and
a scratch shell has neither.

### Its frame and key surface

The float draws a **heavy** border (`@float_border` overrides it) while every
transient dialog keeps the global `rounded`: the float is a pane you sit and
work in, and the heavier edge separates it from the live window behind it.

Inside the float the prefix drives a nested client, so without care every
binding in this config — kill, create, session switch — fires against the
holder. The holder needs **both** halves of the restriction:

- `key-table float-root` — the client's root table inside the float.
- `prefix None` / `prefix2 None` — **required**. tmux intercepts the prefix key
  *itself* and jumps straight to the built-in `prefix` table, bypassing a custom
  root table entirely. With no prefix to intercept, the `C-b`/`C-a` bindings in
  `float-root` fire and `prefix z` still means "close the float".

## The scratch popup

`prefix Z` opens an **ephemeral** shell in a popup at the active pane's
current directory — poke around next to a running agent without carving a pane
out of the layout. None of the float's machinery: no holder, no state, no
resurrect interaction, no key-table staging, since the popup runs a plain shell
rather than a nested client. `ctrl-d` / `exit` ends it and nothing remains. A
*persistent* variant is a `roadmap.md` proposal.

**The scratch must not look like the float.** Ctrl-d in a float kills a real
process the user cares about; ctrl-d in a scratch is the way out. Opposite
semantics, so opposite dress: the scratch is smaller (75% vs 90%) and keeps the
transient-dialog `rounded` border while the float wears `heavy`
(`@scratch_border` overrides it).

## Restore and recovery

Float state lives in pane-local user options, so it moves with the pane and two
floats never collide. Setup publishes recovery state before the destructive move
and writes the phase last; a restore claims the pane atomically, and so does
stealing an expired claim. The comments in `float_pane` and `restore_pane`
carry the reasons.

### Restore is optimistic, not a replay

`select-layout` restores geometry but not pane identity, so restore permutes the
panes back to the recorded order first, then applies the layout — and only when
the source window still matches the snapshot taken after the break.

| Source window on restore | What happens |
|---|---|
| matches the expected snapshot | exact restore — permute to recorded order, then apply the saved layout |
| same panes, different geometry | another client rearranged it; restore identity order only and let their layout stand |
| panes added or removed | degraded — the pane comes home, live layout untouched |
| window gone, session alive | rebuilt near the recorded index/name |
| session gone | holder is renamed into a visible `recovered-*` session |

The pane is **never** killed to satisfy cleanup. `restore` is idempotent, and a
sweep on `client-attached` is the backstop for a SIGKILL'd container; it leaves
a holder with an attached client alone, because that is a live float.

### Why resurrect saves go through a wrapper

A snapshot taken mid-float is unrecoverable: it records the source window without
the pane, plus a `_float_*` session holding it, and nothing in resurrect's format
relinks them. So both save paths — continuum's timer and `prefix C-s` — run
`tmux-resurrect-save.sh`, which normalises every float first (`tmux.conf` wires
both after tpm).

**It fails closed.** If a float cannot be normalised, `prepare-save` returns
non-zero and the wrapper does *not* hand off. Resurrect overwrites the previous
snapshot, so saving anyway would trade a good save for a broken one; skipping
keeps the last good save, and the user gets a message saying why.

## Native floating panes are filtered everywhere

`prefix *` (stock, 3.7) creates a native floating pane. Those are counted by
`#{window_panes}` and embedded in `#{window_layout}`, so every pane list, count,
and comparison in both scripts filters on `#{pane_floating_flag}`; otherwise a
stray float corrupts a snapshot or lets the float break out the last real tiled
pane. Pane mode refuses to move them — tmux says `cannot swap floating panes`.

## Traps

- **A `-c <tty>` target can resolve to a ghost.** A client suspended and never
  resumed shares the live client's tty name, precedes it in the lookup, and is
  hidden from `list-clients`, so a popup aimed at it draws onto a stopped tty.
  Every popup opened from a script passes its client through `live_client()`
  (`lib/tmux-common.sh`, which explains the lookup). To diagnose,
  `tmux display -p -c <tty> '#{client_pid} #{client_flags}'` shows `suspended`
  while `list-clients` shows a different pid; to cure, `kill -9` the stopped
  `tmux attach` in the outer shell's job table.

Traps that apply to any tmux script are in `tmux-scripting.md` § Traps.

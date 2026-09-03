# Floating zoom & pane mode — design notes

One control plane for moving panes around, in three parts:

- **`prefix z`** — maximize the current pane into a *floating* overlay instead of
  tmux's all-or-nothing zoom, so the rest of the window stays visible and live
  behind it. `tmux-float-pane.sh`.
- **`prefix Z`** — an *ephemeral* scratch shell in a popup at the current
  pane's directory; closing the shell disposes of it. Same script, none of the
  holder machinery — see "The scratch popup".
- **`prefix p`** — a sticky "pane mode" key table holding every pane-moving verb
  behind one key. `tmux-pane-relocate.sh` + the `panes` table in `tmux.conf`.

Requires **tmux 3.7b**. Tests: `scripts/tests/test-pane-control.sh` (the
isolation rules a new case must honour are in the repo's `CLAUDE.md`).

---

## The float

### Why the pane is relocated

tmux cannot display an existing pane inside a popup, and tmux 3.7's native
floating panes **cannot convert between floating and tiled** — the 3.6b→3.7
CHANGES lists that as missing, tracked in
[tmux#5135](https://github.com/tmux/tmux/issues/5135) for 3.8. The zoom/float
interaction is itself an open upstream question
([tmux#5258](https://github.com/tmux/tmux/issues/5258)).

So the pane is genuinely relocated: broken out into a detached **holder
session**, which a **container** (a popup running a nested `attach`) displays.
The pane keeps running throughout — only its geometry changes.

`tmux-floax` and the various "floating scratch terminal" recipes use the same
mechanism (dedicated session + popup + attach/detach as the toggle). What is new
here is pointing it at the *current* pane.

**Panes behind the container keep redrawing.** The man page's "Panes are not
updated while a popup is present" is stale — CHANGES has *"Do not freeze output
in panes when a popup is open, let them continue to redraw"*, and a ticker behind
a popup renders live. Only the region the container physically covers is clipped.
That is the whole point of this over `resize-pane -Z`.

### The container adapter

Four functions know the holder is shown by a popup running a nested attach:
`container_restrict_keys` / `container_release_keys` (staging), `open_container`
(presentation), `container_dismiss` (dismissal), and the `container` verb (the
in-container lifecycle). Everything else is container-agnostic, so migrating to a
native floating pane means rewriting those four — not one line.

The adapter is also the only part a second feature should reuse. A persistent
scratch terminal (`roadmap.md`) wants the same presentation and dismissal, but
**not** the holder state machine — that exists to relocate a tiled pane and
restore a source layout, and a scratch shell has neither.

Two tmux behaviours dictate the binding's shape:

- `display-popup` **blocks** its issuing command until dismissed, so the key
  binding calls the script with `run-shell -b`.
- `run-shell` expands `#{...}`; `display-popup` does **not**, in its command
  argument. So the pane id travels as a `run-shell` argument rather than through
  a global env var.

### Its frame

The float draws a **heavy** border while the global `popup-border-lines` stays
`rounded` for the worktree and rename popups. Those are transient dialogs; the
float is a pane you sit and work in, so it earns a heavier edge to separate it
from the live window showing through behind it. Override with
`tmux set -g @float_border <single|rounded|double|heavy|simple|padded|none>` —
`padded` is a solid space-drawn band rather than a line, thicker still, coloured
from `popup-border-style`'s background.

The title is the pane's own label, falling back to its running command.

### Its key surface

Inside the float the prefix drives a nested client, so without care every binding
in this config fires against the holder — including `x`/`X`/`Q` (kill),
`c`/`N`/`|` (create), `W` (worktrees) and `T`/`C-f` (session switches).

The holder needs **both** halves of the restriction:

- `key-table float-root` — the client's root table inside the float.
- `prefix None` / `prefix2 None` — **required**. tmux intercepts the prefix key
  *itself* and jumps straight to the built-in `prefix` table, bypassing a custom
  root table entirely: with a prefix set, `#{client_key_table}` reads `prefix`,
  not `float-prefix`, and the full surface is live. With no prefix to intercept,
  the `C-b`/`C-a` bindings in `float-root` fire and `prefix z` still means "close
  the float".

Keys unbound in a custom root table pass through to the pane, so typing in the
floated app is unaffected — the standard nested-tmux recipe.

One more piece of staging is about the client, not keys: the holder sets
`detach-on-destroy on`, session-local. When the floated pane's process exits
*inside* the float (`:q` in a floated nvim), the holder — whose only content it
is — is destroyed with the nested client still attached, and this config's
global `detach-on-destroy off` would re-home that client onto the most recently
active session. The popup then becomes a live **mirror** of the session behind
it, with the full key surface (float-root died with the holder): `prefix z`
digs a *deeper* float instead of closing, and ctrl-d drives the real panes
through the glass. tmux reads the option from the dying session, so the
holder-local `on` detaches the client instead — the blocking attach returns,
restore runs (a no-op; the pane is gone), the popup closes, and the global
preference is untouched. Shipped as a live incident (2026-08-14); pinned by
T25.

## The scratch popup

`prefix Z` opens an **ephemeral** shell in a popup at the active pane's
current directory — poke around next to a running agent without carving a pane
out of the layout first. Deliberately none of the float's machinery: no holder,
no state, no resurrect interaction, and no key-table staging — the popup runs a
plain shell, not a nested tmux client, so the outer prefix surface is never
inherited. The popup's lifecycle *is* the garbage collection: `ctrl-d` / `exit`
ends the shell, `display-popup -E` reaps the popup, nothing remains.

This is the second consumer the container-adapter note above anticipated — and
it shares only the presentation conventions (geometry, border validation,
title), exactly as prescribed: the holder state machine exists to relocate a
tiled pane and restore a source layout, and a scratch shell has neither.

**The scratch must not look like the float.** Ctrl-d in a float kills a real
process the user cares about; ctrl-d in a scratch is the way out. Opposite
semantics, so opposite dress: the scratch is smaller (75% vs 90%) and keeps the
transient-dialog `rounded` border while the float wears `heavy`. Override with
`tmux set -g @scratch_border <...>`, same values as `@float_border`.

Two small affordances: `SCRATCH_SRC_PANE` rides into the popup's environment so
a script inside can `send-keys` back to the pane it was opened from, and
`SCRATCH_CMD` is the testing seam standing in for the interactive shell (T26
asserts "opens at the pane's cwd" and "leaves nothing behind" through it).

The *persistent* variant (history and cwd surviving across toggles) remains a
`roadmap.md` item; it would re-introduce session naming and idle GC, which is
exactly the machinery this deliberately does not have.

## Restore and recovery

### State lives on the pane

All float metadata is in pane-local user options (`@fl_*`), so it travels with
the pane and two panes can be floated at once without colliding. The rename-pane
popup stashes context in a *global* env var, which races when two clients act at
once — nothing here does that.

### Two transaction rules

**Publish recovery state before the destructive move — and the phase last.** The
pane leaving its window and the metadata saying where it came from must not be
separated by a window in which the process can die: a marked holder containing a
live pane with no `@fl_*` is unrecoverable, and the pane sits invisible in an
internal session.

Order *within* the publication matters just as much. `@fl_phase` is what marks a
pane as mid-float, and `toggle` refuses any pane that has one — so a phase
written before the metadata means a death mid-publication leaves the pane at
home, wedged, and unfloatable forever. Writing it last makes the only interrupted
state a pane carrying stray metadata and no phase, which is inert.

Recovery decides "moved" or "not" from **where the pane is now**, not from what
was recorded: a pane outside any marked holder never moved, so the whole thing
rolls back and the holder — whose only content is the placeholder shell — is
dropped rather than surfaced as a junk `recovered-*` session.

**Claim the restore atomically, including the steal.** `set-option -o` is
set-if-absent: it fails with `already set: …` and preserves the existing value.
Overwriting `@fl_phase` is *not* a lock — every caller seeing any phase proceeds,
so two restorers run the same join + permutation + layout replay and corrupt the
result (`%0 %1 %2` comes back `%0 %2 %1`). That path is directly reachable:
`prepare_save` dismisses the container, waking its restore, then restores itself.

The claim carries a timestamp and is stealable after `FLOAT_CLAIM_TTL` so a
restorer killed mid-flight cannot wedge the pane forever — but **the steal has to
be serialized too**. A plain overwrite let every contender that saw the same
expired claim take it and proceed, straight back onto the corruption path. It is
a compare-and-set: `if-shell -F` evaluates "is the claim still exactly the stale
value I saw" and queues the write as one unit on the server's command queue, and
the winner is whoever's value survives a re-read.

### Restore is optimistic, not a replay

`select-layout <string>` restores **geometry but not identity**: the layout string
addresses panes by index order, so a naive break/join round trip on `%0 %1 %2`
comes back as `%0 %2 %1` with the geometry "right" and the wrong panes in the
slots. Restore therefore permutes panes back to the recorded order with
`swap-pane` **first**, then applies the layout — and only when the source window
still matches the recorded *expected post-break* snapshot.

| Source window on restore | What happens |
|---|---|
| matches the expected snapshot | exact restore — permute to recorded order, then apply the saved layout |
| same panes, different geometry | another client rearranged it; restore identity order only and let their layout stand |
| panes added or removed | degraded — the pane comes home, live layout untouched |
| window gone, session alive | rebuilt near the recorded index/name |
| session gone | holder is renamed into a visible `recovered-*` session |

The pane is **never** killed to satisfy cleanup.

### Failure paths

`restore` is idempotent, and the container's own shell calls it on every ordinary
exit (`prefix z`, `prefix d`, the client being killed). Presentation can also
fail outright — a bad `@float_border`, no client to draw on — so `float_pane`
restores after `open_container` returns; otherwise a float whose container never
opened would leave the pane in an unattached holder, off screen, with a live
phase.

The backstop for a SIGKILL'd container is a **sweep on `client-attached`**;
`surface_orphan_holders` is the last resort, turning a marked holder whose panes
carry no state at all into a normal `recovered-*` session rather than leaving it
hidden.

The sweep enumerates two things, not one: panes inside marked holders, **and any
pane carrying a phase while sitting outside one**. The second is a float
interrupted before its move completed — still in its own window, so no holder
lists it, yet phased so `toggle` refuses it. Scanning panes directly rather than
trusting a marker on the holder means this holds however the interruption left
things.

Two things the sweep must get right:

- **A live float is not stranded.** The container attaching to the holder *is* a
  `client-attached` event; a sweep ignoring that restores the pane the instant the
  float opens, silently undoing the feature. Holders with an attached client are
  skipped.
- **A grace window** covers the gap between `break-pane` and the container's
  attach, where a holder legitimately has no client yet. Because the sweep only
  runs on attach, it re-checks once after the grace rather than leaving a
  too-young holder unexamined until the next attach.

`prepare-save` uses the opposite predicate — it normalises *every* float, live
ones included.

### Why resurrect saves go through a wrapper

A snapshot taken mid-float is unrecoverable: it records the source window without
the pane, plus a `_float_*` session holding it, and resurrect's format carries no
pane user options to relink them (pane ids do not survive a restart either).
Continuum saves every 15 minutes, so any float outliving a tick is exposed.

There is no pre-save hook — resurrect fires only `post-save-layout` and
`post-save-all`, both too late. But continuum does not call resurrect directly:
it reads `@resurrect-save-script-path` and execs it. Pointing that at
`tmux-resurrect-save.sh` covers the timer; `prefix C-s` is rebound separately
because resurrect binds it straight to its own `save.sh`, bypassing the option.
Both are re-applied **after tpm**, since `resurrect.tmux` sets the option with
`-gq` on every load.

**It fails closed.** If a float cannot be normalised, `prepare-save` returns
non-zero and the wrapper does *not* hand off. Resurrect overwrites the previous
snapshot, so saving anyway would trade a good save for a broken one; skipping
keeps the last good save, and the user gets a message saying why.

## Pane mode

Directional push, the identity-aware undo journal, and mark-and-move are an
independent control surface. Their model and verification live in
`pane-mode.md`.

## Native floating panes are filtered everywhere

`prefix *` (stock, 3.7) creates a native floating pane. Those are counted by
`#{window_panes}` and embedded in `#{window_layout}` as a trailing `<...>`
segment, so every pane list, count, and comparison in both scripts filters on
`#{pane_floating_flag}`. Otherwise a stray float corrupts a snapshot or lets the
float logic break out the last real tiled pane. Pane mode refuses to move them —
tmux says `cannot swap floating panes`.

## Traps that cost real debugging

- **A `-c <tty>` target can resolve to a ghost.** `cmd_find_client` matches by
  tty name, first in attach order, and does **not** skip a suspended client —
  while `list-clients` hides one (`sort_get_clients` drops
  `CLIENT_UNATTACHEDFLAGS`). A client suspended and never resumed (stock
  `suspend-client`, then `tmux attach` again from the same terminal) therefore
  shares the live client's name, precedes it, wins the lookup, and every popup
  is drawn onto a stopped tty: float and scratch both went dark for a day
  (2026-08-16), and the ghost was invisible to `list-clients` the whole time.
  `live_client()` keeps a client name only if the pid it resolves to is one
  `list-clients` shows, else passes no `-c` and lets tmux pick the session's
  most recently active client — on the keypress path, the one that pressed
  the key. Pinned by T27, which manufactures a real ghost. Diagnosis, if it
  ever recurs: `tmux display -p -c <tty> '#{client_pid} #{client_flags}'`
  showing `suspended` while `list-clients` shows a different pid; cure:
  `kill -9` the stopped `tmux attach` in the outer shell's job table.
- **`show-option -t "=name"` reads back empty**, with rc=0. The `=` exact-match
  form is for a target-*session* (`has-session`, `kill-session`, `attach-session`
  take it); `show-option`'s target is a target-*pane*. Using it makes every holder
  look unmarked, so the sweep finds nothing.
- **`IFS= read -r a b c`** disables splitting entirely — the whole line lands in
  `a`. Use `IFS=' '`.
- **A later `unbind` silently kills an earlier `bind`.** `tmux.conf` is a single
  pass; `unbind p` below the pane-mode binding removes it with no error.
- **3.7 needs `fill=` in `message-style`**, or the message bar paints only behind
  its text (the stock default became `bg=yellow,fg=black,fill=yellow`).

# Session board — design

`prefix S` opens one Claude session's steps beside its status and a list of
the other sessions, laid out as lazygit is. The main panel, on the right, is
the steps of the session the key was pressed in, newest first, and with `Tab`
its whole history. The side column holds that session's status (what it is
and where, each label's latest step and the commits since, my latest notes)
above the list of Claude panes, which is for the occasional switch. A popup
too small for the column opens on the status instead, with the steps under
it. It answers "did we run the review here, and what
changed since" without asking the session, which would cost it a turn.

## Who owns what

```text
reading transcripts, events, labels, notes        → claude-steps binary (~/dev/claude-steps)
every fact shown, its colour, its fit to a width  → claude-steps binary
the label set, each one's hue, the snippet files  → claude-steps/.config/claude-steps/config.toml
popup, layout, keys, pane switching, note field   → tmux-steps.sh
which pane runs which session                     → @claude_ctx_sid, set by the context chip (context-chip.md)
```

`claude-steps` reads tmux and the transcript files and writes only the notes
under `~/.local/state/claude-steps/notes/`. What a line means is in
`~/dev/claude-steps/README.md`; the design, and the contracts this script
relies on, are in `~/dev/claude-steps/docs/design.md`. Each panel is one call:
the main panel is `show --no-head`, the status `show --head`, the list
`board --ids --brief`, and a stacked panel `show`. Every fact on screen comes
from the binary, so a new fact, column, colour or glyph belongs there, not in
the script; the script's own words are its chrome: the key hints, the
panels' labels, and the line that says a cut status goes on under the
steps.

## Constraints

- **Nothing reaches a session.** The script never sends keys to a pane and
  never writes into a session's files, and the binary has no network client.
  A reminder that should change what a session's model does belongs in a
  skill, not here.
- **The view states dated facts.** A time is `11m` or `2d`, with `+N`
  commits since, or `read` / `pasted` / `named` in front on the board when
  the latest event was only a file read, a pasted snippet or a prompt.
  Nothing says a step is finished or still valid, and no colour does either:
  a hue names a label or the kind of an item in the status, red marks what
  could not be read.
- **The script asks for colour and gives the width.** fzf reads the binary
  through a pipe, where it paints nothing and fits nothing unless told. The
  side column's width is fixed when the popup opens: `pick` gives the preview
  an absolute size that leaves the column about a third of the popup, and
  exports the width fzf draws a row or a status line in (`STEPS_SIDE`, the
  column less its frame and gutter) for the list and the status; the main
  panel takes fzf's own preview width. A call that skips it prints rows wider
  than the column, which fzf cuts with `··`. S9 pins it.
- **The main panel opens at its top, on the newest step.** A panel that
  follows its output opens on the oldest steps. S7 pins it.
- **The status keeps the list its rows, and its place.** The status box keeps
  the height of the tallest status it has shown, so the list does not move as
  the cursor does, but never more than leaves the list room for up to six
  sessions. A status taller than that is cut, its last line says how many
  lines go on under the steps, and for that session the main panel adds the
  whole status under the steps. S3 and S11 pin it.
- **A popup too small for the side column stacks, status first.** Below 120
  columns or 34 rows the panel on top is the whole session view: the status,
  which is what the popup is opened to read, then the steps, and the list is
  under it. The panel takes the rows the list does not need for up to six
  sessions, and more when the status the cursor starts on would not fit
  whole, while the list keeps three. That status is measured as the panel
  draws it, painted, since a glyph can fold a line, for the first row when
  the pane runs no Claude session. S10 pins it.
- **The main panel's label is the toggle's state.** `Tab` flips it between
  `steps` and `history` (`status · steps` and `status · history` stacked),
  and the panel reads it to choose what to show, so the choice holds while
  the cursor moves. S8 and S10 pin it.
- **A row acts on its session id, not its pane.** `board --ids --brief`
  prints the pane id and the session id on every row. The status, the steps
  and the note use the session id, because a pane can move to another
  session (`/clear`, `/resume`) while the popup is open, and a note typed
  against a row belongs to the session that row showed. S2 pins it.
- **After a note, the load redraws the status.** fzf expands every `{2}` in
  a key's actions when the key is pressed, before its reload, and a reload
  that keeps the cursor fires no focus. So the note's key only reloads, and
  the `load` that follows redraws the main panel and the status for the row
  as it now reads: its pane may run another session by then. S2 and S3 pin
  it.
- **The status is in the terminal's own colour.** fzf draws a header in its
  muted header colour; the status overrides that, and the key hints keep it.
  S12 pins it.
- **The note is free text.** fzf is the line editor, as in the rename popup: a
  shell line editor does not edit inside a popup.
- **The cursor starts on the pane the key was pressed in** and stays where it
  is after a note reloads the list. S1 and S3 pin both.

## Keys

`Enter` switches to the row's pane · `Tab` flips the main panel between the
session's steps and its whole history · `ctrl-n` writes a note for the row's
session · `ctrl-d` / `ctrl-u` scroll the main panel · `Esc` closes.

Outside the popup: `claude-steps show` in any Claude pane prints that
session (`--all` for its history), `claude-steps note <pane or session>
<text>` writes a note, and `claude-steps check` reports whether Claude Code's
transcript format has moved under the reader.

## Tests

`tests/test-steps-popup.py` drives the real fzf and the real `claude-steps` on
a private tmux socket with a temporary `HOME`, as many labels as the author's
own configuration and a theme palette. It runs the popup's view in a pane,
where the screen can be captured, on a client wide enough for the side
column; S10 and S11 resize the pane for the stacked layout and for a status
taller than its room. S6 alone presses `prefix S` as `tmux.conf` binds it and
reads the popup from the client's terminal.

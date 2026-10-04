# Session board — design

`prefix S` opens the session board: one row per pane running Claude, with when
each labelled step last ran in that session and the commits since, the newest
round with no collect seen, its pull requests and my latest note. The preview
is the session, newest first: its labels, its notes and its steps, and with
`Tab` its whole history. It answers "did we run the review here, and what
changed since" without asking the session, which would cost it a turn.

## Who owns what

```text
reading transcripts, events, labels, notes        → claude-steps binary (~/dev/claude-steps)
every line shown, its colour, its fit to a width  → claude-steps binary
the label set (board columns) and each one's hue  → claude-steps/.config/claude-steps/config.toml
popup, keys, pane switching, note field           → tmux-steps.sh
which pane runs which session                     → @claude_ctx_sid, set by the context chip (context-chip.md)
```

`claude-steps` reads tmux and the transcript files and writes only the notes
under `~/.local/state/claude-steps/notes/`. What a line means is in
`~/dev/claude-steps/README.md`; the design, and the contracts this script
relies on, are in `~/dev/claude-steps/docs/design.md`. `tmux-steps.sh` shows only
what the binary prints: a new fact, column or colour belongs in the binary,
not in the script.

## Constraints

- **Nothing reaches a session.** The script never sends keys to a pane and
  never writes into a session's files, and the binary has no network client.
  A reminder that should change what a session's model does belongs in a
  skill, not here.
- **The view states dated facts.** A cell is a time (`11m`, `2d`), with `+N`
  commits since, or `read` / `named` in front when the latest event was only
  a file read or only a prompt. Nothing says a step is finished or still
  valid, and no colour does either: a hue names a label, red marks what could
  not be read.
- **The script asks for colour and gives the width.** fzf reads the binary
  through a pipe, where it paints nothing and fits nothing unless told. A
  call that skips the script's `board` or `preview` prints plain rows wider
  than the list, and fzf cuts a wide row at its right end, where the note is.
  S9 pins it.
- **The preview opens at its top.** A session's labels are its first lines; a
  preview that follows its output opens on the oldest steps. S7 pins it.
- **The preview's label is the toggle's state.** `Tab` flips it between
  `steps` and `history`, and the preview reads it to choose what to show, so
  the choice holds while the cursor moves. S8 pins it.
- **A row acts on its session id, not its pane.** `board --ids` prints the
  pane id and the session id on every row. The preview and the note use the
  session id, because a pane can move to another session (`/clear`,
  `/resume`) while the board is open, and a note typed against a row belongs
  to the session that row showed. S2 pins it.
- **The note is free text.** fzf is the line editor, as in the rename popup: a
  shell line editor does not edit inside a popup.
- **The cursor starts on the pane the key was pressed in** and stays where it
  is after a note reloads the list. S1 and S3 pin both.

## Keys

`Enter` switches to the row's pane · `Tab` flips the preview between the
session's steps and its whole history · `ctrl-n` writes a note for the row's
session · `ctrl-d` / `ctrl-u` scroll the preview · `Esc` closes.

Outside the popup: `claude-steps show` in any Claude pane prints that
session (`--all` for its history), `claude-steps note <pane or session>
<text>` writes a note, and `claude-steps check` reports whether Claude Code's
transcript format has moved under the reader.

## Tests

`tests/test-steps-popup.py` drives the real fzf and the real `claude-steps` on
a private tmux socket with a temporary `HOME`. It runs the board in a pane,
where the screen can be captured; S6 alone presses `prefix S` as `tmux.conf`
binds it and reads the popup from the client's terminal.

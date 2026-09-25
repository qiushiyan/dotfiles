# Claude Ctrl+G reply reference

When Claude Code's Ctrl+G opens a prompt in Neovim, a read-only window beside
the draft shows the assistant reply being answered. Agents often end a turn
with a list of questions taller than the pane, and the Ctrl+G editor used to
hide them entirely. Sibling of `docs/claude-prompt-completion.md`, which owns
how the prompt buffer is spawned.

```
nvim/.config/nvim/lua/claude-prompt/
  init.lua        # is_prompt_file(): the one Ctrl+G buffer test; setup()
  transcript.lua  # session resolution + reply extraction
  reference.lua   # the window, its keys, its lifecycle
nvim/.config/nvim/tests/test-claude-prompt-reference.sh
```

## Using it

The window opens automatically on Ctrl+G, beside the draft when the pane is at
least 100 columns wide and above it otherwise. It shows the newest reply's
**final message**, the text after its last tool call. The cursor stays in the
draft.

- **From the draft:** `[r` / `]r` step to the previous or next reply;
  `<C-f>` / `<C-b>` scroll the reference half a page.
- **In the reference:** `[r` / `]r` as above, `f` toggles final message /
  whole turn (progress notes between tool calls included), `q` closes it.
- **`:ClaudeReply`** reopens it or reloads it on the newest reply.
- **Half-height pane:** press tmux `prefix z` (float the pane) before Ctrl+G.
  The tool deliberately doesn't zoom: `resize-pane -Z` toggles, so restoring
  it blindly can undo your own zoom.

Nothing is ever written into the draft. The prompt file holds only what you
typed, and that is all Claude receives.

## Invariants

- **`:wq` in the draft must end Neovim.** A `QuitPre` autocmd closes the
  reference window first; without it, the reference keeps the editor alive and
  Claude waits forever. `QuitPre` fires after `:wq`'s write, so a failed write
  keeps both windows.
- **Setup runs from `lua/custom/init.lua`, not the VeryLazy autocmds file,**
  which would miss the startup buffer.
- **Prompt-buffer recognition lives only in `claude-prompt.is_prompt_file`.**
  Skill completion, this window, and the tmux path-copy exclusion in
  `config/autocmds.lua` all call it. The check is anchored on the
  `claude-<uid>/` parent directory, so a project file named
  `claude-prompt-notes.md` doesn't count.

## Where the text comes from

It reads the session transcript, never the screen: tmux or Ghostty capture
returns wrapped text with the TUI's decorations. Everything below relies on
Claude Code's internal on-disk state, so any failure is reported as a
one-line notice and the window stays closed:

1. **Session:** walk up from Neovim's parent process to the nearest pid
   with `$CLAUDE_CONFIG_DIR/sessions/<pid>.json` (default `~/.claude`;
   non-default accounts set the variable, and the editor inherits it). Claude
   spawns `$EDITOR` as a direct child (verified in a live run in September
   2026), but the walk tolerates a wrapper shell. The fallback is the pane's
   `@claude_ctx_sid` from the context chip. The file's `procStart` isn't
   compared with `ps` because the two disagree by an hour.
2. **Transcript:** the single match of `projects/*/<sessionId>.jsonl`. No
   project-directory encoding is reconstructed.
3. **Replies:** only the last 32 MB is decoded, so transcripts of 80 MB and
   up still open in tens of milliseconds, and history stops where that window
   starts. The active branch is the `parentUuid` chain of the newest record,
   so replies abandoned by `/rewind` drop out. A user record starts a new turn
   unless it is `isMeta` or carries a `tool_result`. A half-written final
   line is skipped.

A session with no messages yet has no transcript, so the notice says so.

## Deliberately not done

- **Codex:** its rollouts under `~/.codex/sessions/` would be a second
  backend for `transcript.lua`.
- **A tmux key for typing straight into Claude's input:** Ctrl+G covers it.
  If one is added, it must be a side pane: a popup takes focus.
- **Parsing questions into an answer skeleton:** picking questions out of
  prose is heuristic, and the user answers in free text anyway.
- **A Stop-hook snapshot of `last_assistant_message`:** Claude's docs warn
  the transcript can lag when Stop fires, but Ctrl+G comes seconds later.
  Revisit only if the reference is ever observed missing the newest reply.

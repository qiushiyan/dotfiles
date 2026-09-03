# add-theme — evidence log

One entry per improve-tool mining pass: the corpus, the signatures that
selected it, each friction's count with the facet that produced it, its
verdict, and where it landed. A count without its predicate cannot be re-run.

## 2026-09-03 — first pass: the recipe leaves docs/theming.md for this skill

Corpus: the 5 theme ports since 2026-08-20 — `37b894a9` vitesse light soft,
`ab07313a` vitesse black, `5c11d3b9` night owl, `1882af39` orng light,
`f198f15b` forest night (the seed, this session). Ledger
`add-theme-frictions.md` in the seed's scratchpad.

Measurement: sessions with `sessions.project LIKE '%dotfiles%'` whose
`tool_calls` (`Edit`/`Write`, or `Bash` with `cat >` / `sed -i` / `python3 -`)
named theme-set, zsh/theme.zsh, statusline-command.sh, zen.omp.json,
tmux/themes/, ghostty/themes/, nvim/colors/, config/theme.lua,
config/palette.lua or docs/theming.md, minus the context-chip sessions that
share statusline-command.sh (18 matched, 4 were ports). Door = first user turn
(`role='user' AND content_type='text'`, earliest); cost = tool calls, `is_error`
rows, minutes to the user's next turn; doc read = a `Read`/`Bash` naming
docs/theming.md before the session's first theme write. Next window: ports
after 2026-09-03, invoked as `/add-theme` (`messages.skill='add-theme'` or
`<command-name>/add-theme`) or by the natural-language door.

| friction | count | reading | verdict → layer |
|---|---|---|---|
| the six-file insert rebuilt by hand as a throwaway patch script | 5/5 ports (bash heredoc writes 1, 6, 6, 8, 1; 2 anchor errors: `37b894a9`, `5c11d3b9`) | observed | user: instructions — the patch script is the skill's worked example, anchors filled; a scaffold engine was offered and declined |
| the palette's location rediscovered per port | 5/5 (Zed ×3, Ghostty built-in, a repo; `1882af39` spent 3 commands finding the Zed extension dir) | observed | assumed, reversible: instructions — the source table in step 1 |
| procedure and internals in one 200-line doc, read in full 4/4 before the first write; gotchas accreted into the recipe after `37b894a9`'s "find frictions… fix in docs/theming" | 4/4 | observed | user (the request): shape — the recipe is this skill, the doc keeps the model; the supported-themes cache became a pointer at `THEMES` |
| `Lazy! sync` re-pinned unrelated plugins | 1/5 (`5c11d3b9`) | observed | assumed: instructions — `Lazy! install` + one-line lock diff |
| a port rejected afterwards, removed by hand around unrelated edits | 1/5 (`ab07313a`) | inferred | user: the skill ends switched on and committed; removal is one revert |
| door: natural language 5/5, slash 0/5 | 5/5 | observed | user: user-invoked `/add-theme` anyway; CLAUDE.md routes to the file so the natural-language door still reads it |

Nothing landed on the engine. User's vision: none withheld — "there isn't
much that I avoid doing"; removal and light themes are not costly.

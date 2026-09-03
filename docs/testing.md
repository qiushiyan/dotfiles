# Tests

This repo is mostly configuration, so there is no build. The bash suites take an
optional list of case ids to narrow the run:

```bash
bash tmux/.config/tmux/scripts/tests/test-pane-control.sh        [T5 T14 …]
bash tmux/.config/tmux/scripts/tests/test-claude-context-chip.sh [C2 C7 …]
bash tmux/.config/tmux/scripts/tests/test-worktree-core.sh       [W2 W10 …]
zsh  zsh/.config/zsh/tests/claude-sessions.test.zsh              # runs whole
zsh  zsh/.config/zsh/tests/startup-options.test.zsh              # runs whole
zsh  zsh/.config/zsh/tests/theme-sync.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/cwd-guard.test.zsh                    # runs whole
zsh  zsh/.config/zsh/tests/stow-reach.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh         # runs whole
```

Each suite owns one boundary:

| Suite | Contract |
|---|---|
| pane control | float, restore, and pane-mode transactions on an isolated tmux socket |
| context chip | publication, shedding, cleanup, and quota refresh without the live cache |
| worktree core | tmux-free base, slot, merge, snapshot, and reap rules |
| Claude sessions | shared-store topology and repair against a throwaway `$HOME` |
| startup options | non-interactive `.zshenv` state in a clean `zsh -c` |
| theme sync | startup + precmd switching against a throwaway `$HOME` |
| cwd guard | deleted-directory recovery without touching the caller |
| Stow reach | root-memory and package-ignore invariants from the working tree |
| bypass guard | dormant hook logic through synthetic PreToolUse payloads |

The table is a routing map. Case ids and complete behavior inventories stay in
the suites.

The chip suite drives the real `statusline-command.sh` from the **working tree**
rather than the stowed copy, which is what lets it grade a branch instead of
whatever happens to be installed.

## A test that escapes its sandbox corrupts live state

This is the constraint that governs every suite here. Because the repo's files _are_
the user's live configuration, a test that reaches past its sandbox doesn't fail
— it quietly damages the running system. Both escape routes are silent, so a new
case has to close them deliberately.

**Drive tmux only through the test socket.** Every call goes through the `R()`
helper with `$TMUX` pointed at the suite's own socket. A call that skips it
falls through to the default socket — the real server — where the test's pane
ids don't exist, so everything no-ops and the assertions pass for the wrong
reason. A green suite that tested nothing is the failure mode to fear here.

**Redirect shared state that lives _outside_ tmux.** resurrect's save directory
is a single path shared by all servers unless `@resurrect-dir` is set, so a test
reaching the real `save.sh` overwrites the user's session snapshot; `fresh()`
sandboxes it and T21 asserts the real directory was never touched. Likewise
the sessions toolkit reads and writes under `$HOME`, so every case in its suite
exports a throwaway `HOME` before running anything — ad-hoc verification that
skips the override edits the user's real accounts and session state. Global
patterns like `pkill` need the same care.

Each suite carries a guard case for exactly this reason; when you add state that
crosses the sandbox boundary, add the guard alongside it. The chip suite's C9 is
that guard, and it has already earned its keep: the statusline gained a detached
quota refresher, and the first run afterwards caught it running the real
`headroom` against the real accounts root and writing the user's live
`~/.cache`. The lever that closed it, `CLAUDE_CTX_REFRESH_CMD`, is worth copying
in shape — unset means production, set-but-empty disables the spawn, and set to
a path substitutes a stub. A lever that could only disable would have bought
isolation by leaving the trigger, the throttle and the lock test permanently
unexercised, which is how they would rot; C22 drives all three against the stub.

**Watch what runs _inside_ the sandbox, too.** A test pane running the user's
interactive shell loads `~/.zshrc`, and this config's zsh hooks are production
code with opinions: the `precmd` sweep exists to clear a Claude context chip the
moment a prompt returns. In a real pane that inference is right; in a test pane
it makes the shell a **second writer**, racing the case for the same state and
winning whenever zsh finishes loading last. The chip suite gives its panes a
non-shell process for that reason, and the timing dependence is invisible while
it happens to pass — it survived several green runs before it started failing.

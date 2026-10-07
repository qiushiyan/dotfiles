# Tests

This repo is mostly configuration, so there is no build. The bash suites take an
optional list of case ids to narrow the run:

```bash
bash tmux/.config/tmux/scripts/tests/test-pane-control.sh        [T5 T14 …]
bash tmux/.config/tmux/scripts/tests/test-claude-context-chip.sh [C2 C7 …]
python3 tmux/.config/tmux/scripts/tests/test-gwt-popup.py        # requires gwt, tmux, fzf
python3 tmux/.config/tmux/scripts/tests/test-popup-overlay.py --stock <known-broken-binary> --candidate <candidate-binary>
python3 tmux/.config/tmux/scripts/tests/test-cout.py            # requires tmux, zsh, oh-my-posh, cout (or COUT_BIN)
python3 tmux/.config/tmux/scripts/tests/test-steps-popup.py     # requires claude-steps, tmux, fzf
zsh  zsh/.config/zsh/tests/claude-launch.test.zsh                # runs whole
zsh  zsh/.config/zsh/tests/startup-options.test.zsh              # runs whole
zsh  zsh/.config/zsh/tests/portability.test.zsh                 # requires fzf, zoxide, oh-my-posh
zsh  zsh/.config/zsh/tests/theme-sync.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/gwt.test.zsh                         # requires gwt on PATH
zsh  zsh/.config/zsh/tests/git-wrapper.test.zsh                 # runs whole
zsh  zsh/.config/zsh/tests/cwd-guard.test.zsh                    # runs whole
zsh  zsh/.config/zsh/tests/stow-reach.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/block-dangerous-git.test.zsh          # runs whole
zsh  zsh/.config/zsh/tests/rm-guard.test.zsh                     # runs whole
zsh  zsh/.config/zsh/tests/account-launchers.test.zsh            # runs whole
python3 scripts/.local/share/dotfiles/tests/test_skill_sync.py # requires uv
bash scripts/.local/share/dotfiles/tests/test-toclip.sh         [K1 K5 …]
bash scripts/.local/share/dotfiles/tests/test-aws-login.sh    [A1 A4 …]
bash scripts/.local/share/dotfiles/tests/test-snapshot.sh     [S1 S4 …]
bash claude/.claude/skills/obelisk/tests/test-obq.sh          [O1 O6 …]
bash .claude/hooks/test-machine-context.sh                     # runs whole
bash nvim/.config/nvim/tests/test-claude-prompt-reference.sh    # runs whole
bash nvim/.config/nvim/tests/test-statusline-band.sh           # runs whole
```

Each suite owns one boundary:

| Suite | Contract |
|---|---|
| pane control | float, restore (every degraded branch), sweep and save, pane-mode, and rename-popup transactions, plus the shared script library's contract (existence checks, float state, live client, palette colours), on an isolated tmux socket against the working tree |
| context chip | publication, shedding, cleanup, and quota refresh without the live cache; one agent-status vocabulary across the statusline, owner, border, and zsh; the prompt sweep in a single tmux round trip; the statusline's own line (branch, counts, display path, unknown-theme fallback); the test server's plugins reach only the sandbox `HOME` |
| gwt popup | real creation uses caller HEAD, configured root, seeding, and window delivery, and copies the new path; the bare first paint shows before a held-back `gwt list` and keeps a query and a mark across the swap; ctrl-y copies the highlighted or marked paths; both copies go through a stub `toclip`; the merged tag and ctrl-g both read gwt's `removable`, leaving unmerged, locked, and unprobed (status-error) work and prefix-named windows; ctrl-x keeps a worktree gwt cannot snapshot, keeps declined dirty work, and on acceptance kills another session's window on it before gwt runs, prints the snapshot ref, and force-deletes an unmerged branch only with its tip kept; removal itself (refusals, snapshots, recovery refs, expiry, trash sweep) is tested in `~/dev/gwt`; private tmux socket |
| popup overlay | candidate preserves the popup during redraws and answers promptly while a client narrower than its window draws pane status; stock must reproduce each defect on private sockets ([package runbook](tmux-popup-patch.md)) |
| cout | the installed `cout` binary end to end (or `$COUT_BIN`): command/output pairing across nested shells, indexed copies, recorder retention/cleanup, terminal rendering with the real transient prompt, and `prefix o` leaving no popup; private tmux sockets, a temporary home, and a fake clipboard isolate state, and every store path is checked to lie inside the sandbox before a delete. Parser, store, and replay unit tests are in `~/dev/cout` |
| session board | the `prefix S` popup lists every Claude pane and starts on the pane the key was pressed in; a note goes to the session on the row even after its pane moved to another session; the list reloads with the note and keeps its cursor and its place; the main panel opens on the newest steps however long the session is, the status beside it holds the labels, and Tab flips the panel to the whole history and back; the binary's colours reach the popup, the status is in the terminal's colour and the key hints muted (S12), and a long title's list row is cut by the binary to the side column (S9); a status taller than its room is cut, whole under the steps, and never takes the list's rows (S11); a popup too small for the side column stacks and opens on the session's whole status with the steps and Tab's history under it, the panel sized for the status as it is painted, of the row the cursor starts on, with five sessions in the list (S10); Enter switches a real client on a pty; the `bind-key S` line from `tmux.conf`, pressed on that client, opens the popup (S6); private tmux socket, a temporary `HOME` holding the transcripts and notes, and S5 asserts the real notes directory is untouched. Transcript reading is tested in `~/dev/claude-steps` |
| Claude launch | what `claude.zsh`'s launchers add to headroom (refusal without it, named routing, workspace effort, `--fast`, x-select's cd) through a headroom built from `~/dev/headroom`, against a throwaway `$HOME`; topology, retention and environment policy are tested in headroom |
| startup options | non-interactive `.zshenv` state in a clean `zsh -c` |
| portability | the package starts silent on a bare `$HOME` from an empty environment, loads every module, and loads a host file only from `~/.config/machine`; interactive shells keep `git.zsh`'s `git()` and one fpath whatever they inherit; interactive cases run on a pty |
| theme sync | startup + precmd switching against a throwaway `$HOME`; every theme-set name applies without error |
| gwt shell | the subcommand list (checked against `gwt --help`), completion, parent-shell entry and `--cd` refusals, and configured placement in a temporary home with a stub `toclip`; caller HEAD and seeding are tested in `~/dev/gwt` |
| git wrapper | the branch guard fires on a stale base and follows `gitguard on/off`; under the working tree's `git/.gitconfig`, planlab pushes (clone and worktree) get `repo.pushArgs` and skip the pre-push hook, others run it; local repositories under a temporary home, no user git config, and a check that the live guard marker is untouched |
| cwd guard | deleted-directory recovery without touching the caller |
| Stow reach | root-memory and package-ignore invariants from the working tree, over the packages `make -s list` names; the list leaves out non-package directories and names only the launchd package of the machine `~/.config/machine` names, and `scripts/` keeps its entry points out of `HOME`, through `make list` and a `stow -n` dry run in scratch directories and a scratch `HOME` |
| dangerous-git hook | force and mirror pushes and work-destroying commands (forced checkouts and switches, whole-tree pathspecs included) refused in any argument order, behind wrappers and inside command substitutions and expanding heredocs; force-with-lease and remote deletes passed; the `branch -D` gate and its per-command bypass; quoted text, quoted heredoc bodies and comments inert; synthetic PreToolUse payloads under the PATH `python3` and `/usr/bin/python3` (3.9) |
| rm guard | a recursive rm of a protected path is refused in every spelling (trailing slash, `..`, symlink, literal `~`, /var→/private/var) and every other call passes through unchanged; probes see only a logging stub `rm` |
| account launchers | which x-*/cx-* names exist and which account each hands headroom (unique local part only, never the primary's or a utility's name, ambiguity drops the alias, `.lock` skipped); stub headroom, throwaway `$HOME` |
| skill sync | invocation overrides, refreshed cloud exclusions, runtime metadata recovery, metadata preservation, byte-exact document copies, validation before writes, and symlink destinations; every case runs a copied script with a temporary home, manifests, and sentinel checkout, so scope regressions stay in the sandbox |
| toclip | which clipboard a copy reaches: pbcopy at the screen, the ssh client (not tmux's activity pick) inside tmux, the buffer kept for oversize payloads; browser-clip follows the same routing for a URL, whatever ssh variables the pane inherited; private tmux socket, real clients on ptys, stub pbcopy and open, and K8 asserts the real clipboard is untouched |
| aws-login | sign out, sign in, verify, then stamp; the device-code flow only on the mini marker; `--status` from the stamp; a stub `aws` on PATH records the calls, a temporary `HOME` holds the stamp, and A8 asserts the real state directory is untouched |
| snapshot | a plain run deletes the previous plain run's snapshot only after the new one exists; `--daily` prunes by age and stands down once Time Machine has a destination; a stub `tmutil` on PATH keeps the snapshot dates in a sandbox file, a temporary `HOME` holds the state, and S7 asserts the real state directory is untouched |
| obq | the obelisk skill's wrapper returns one object keyed by machine from this machine's engine and the other's; a machine that is unreachable or never answers is a warning with exit 0, an engine failure or an empty answer is exit 1; the script path reaches the engine here as typed and a search nonce stays on this machine; stub `obelisk` and `ssh` on a PATH without the real engine, a temporary `HOME` holding the tree's twin manifest, the other machine a sandbox directory whose commands run under zsh, and O13 asserts the stubs were reached and nothing is left behind |
| machine context | the session-start hook prints the text of the machine `~/.config/machine` names, then `twin`'s recorded state of this checkout, and reports a machine it cannot name instead of guessing; a `twin` that is absent or slower than the hook's limit adds nothing; a stub `twin` on a bare PATH, so the real one never runs. `twin`'s own behaviour is tested in `~/dev/twin` |
| Claude reply reference | Ctrl+G buffers open the right reply, history and whole-turn views, `:wq` exits with the draft byte-exact, closing either window never strands the editor, the layout follows pane width, lookalike files are ignored; the working tree's full Neovim config against a fixture `CLAUDE_CONFIG_DIR` naming the suite as the claude process, temp XDG state, tmux unset |
| statusline band | the lualine band takes the active colorscheme's `StatusLine` bg and `Normal` fg at startup and after a theme-file rewrite that the live watcher applies; the working tree's full Neovim config, a temporary `HOME` holding the theme file, temp XDG state, tmux unset |

The table is a routing map. Case ids and complete behavior inventories stay in
the suites.

The chip and pane-control suites drive the working tree's scripts rather than
the stowed copies, which is what lets them grade a branch instead of whatever
happens to be installed. Both start the test server under a sandbox `HOME`
whose `~/.config/tmux` links the tree's `tmux.conf`, scripts and themes and the
installed plugins.

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
sandboxes it and T21 asserts the real directory was never touched. The test
server's own plugins are the same hazard: TPM reads its plugin list from
`$HOME/.config/tmux/tmux.conf`, not tmux's `-f` file, and the plugins act on
`$HOME` (continuum deletes `~/Library/LaunchAgents/Tmux.Start.plist` on every
load, and restores a snapshot on start unless `~/tmux_no_auto_restore`
exists). A server started under the caller's `HOME` runs them against the live
machine; one whose sandbox lacks the config link runs with no plugins at all,
and the cases that depend on them pass over nothing. C34 and T12 hold both
down. Likewise headroom reads and writes the account dirs and the session
store under `$HOME`, so every case in the Claude launch and account-launcher
suites exports a throwaway `HOME` before running anything — ad-hoc
verification that skips the override edits the user's real accounts and
session state. Global patterns like `pkill` need the same care.

Each suite carries a guard case for exactly this reason; when you add state that
crosses the sandbox boundary, add the guard alongside it (the chip suite's C9
guards its quota refresher). **Give a spawned side effect a three-way lever,
not an off switch**, in the shape of `CLAUDE_CTX_REFRESH_CMD`: unset means
production, set-but-empty disables the spawn, and set to a path substitutes a
stub. A lever that could only disable would buy isolation by leaving the
trigger and the throttle permanently unexercised; C22 drives both against the
stub.

**Never delete through a path read from state.** A store directory, a pane
option or a manifest field is empty exactly when the thing under test failed,
and `Path("")` is `.`, the process's working directory: a negative control
run from the checkout, a suite against a binary that does nothing, reaches
`shutil.rmtree(Path(""))` and empties the repository, `.git` included.
Before a delete, check that the path is non-empty, absolute
and inside the sandbox (`test-cout.py`'s `store()` is the pattern), and run
suites from a scratch directory so a relative path can only land there. A
negative control is the run where this state is guaranteed to be empty, so it
goes nowhere near the checkout.

**Watch what runs _inside_ the sandbox, too.** A test pane running the user's
interactive shell loads `~/.zshrc`, and this config's zsh hooks are production
code with opinions: the `precmd` sweep exists to clear a Claude context chip the
moment a prompt returns. In a real pane that inference is right; in a test pane
it makes the shell a **second writer**, racing the case for the same state and
winning whenever zsh finishes loading last. The chip suite gives its panes a
non-shell process for that reason; the timing dependence is invisible while it
happens to pass.

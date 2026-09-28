# Tests

This repo is mostly configuration, so there is no build. The bash suites take an
optional list of case ids to narrow the run:

```bash
bash tmux/.config/tmux/scripts/tests/test-pane-control.sh        [T5 T14 …]
bash tmux/.config/tmux/scripts/tests/test-claude-context-chip.sh [C2 C7 …]
bash tmux/.config/tmux/scripts/tests/test-worktree-core.sh       [W15 W36 …]
python3 tmux/.config/tmux/scripts/tests/test-gwt-popup.py        # requires gwt, tmux, fzf
python3 tmux/.config/tmux/scripts/tests/test-popup-overlay.py --stock <known-broken-binary> --candidate <candidate-binary>
python3 tmux/.config/tmux/scripts/tests/test-cout.py            # requires tmux, zsh, oh-my-posh, cout (or COUT_BIN)
zsh  zsh/.config/zsh/tests/claude-sessions.test.zsh              # runs whole
zsh  zsh/.config/zsh/tests/startup-options.test.zsh              # runs whole
zsh  zsh/.config/zsh/tests/portability.test.zsh                 # requires fzf, zoxide, oh-my-posh
zsh  zsh/.config/zsh/tests/theme-sync.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/gwt.test.zsh                         # requires gwt on PATH
zsh  zsh/.config/zsh/tests/git-wrapper.test.zsh                 # runs whole
zsh  zsh/.config/zsh/tests/cwd-guard.test.zsh                    # runs whole
zsh  zsh/.config/zsh/tests/stow-reach.test.zsh                   # runs whole
zsh  zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh         # runs whole
python3 scripts/.local/share/dotfiles/tests/test_skill_sync.py # requires uv
bash scripts/.local/share/dotfiles/tests/test-toclip.sh         [K1 K5 …]
bash scripts/.local/share/dotfiles/tests/test-aws-login.sh    [A1 A4 …]
bash nvim/.config/nvim/tests/test-claude-prompt-reference.sh    # runs whole
```

Each suite owns one boundary:

| Suite | Contract |
|---|---|
| pane control | float, restore, pane-mode, and rename-popup transactions, plus the shared script library's contract (existence checks, live client, palette colours), on an isolated tmux socket |
| context chip | publication, shedding, cleanup, and quota refresh without the live cache; one agent-status vocabulary across the statusline, owner, border, and zsh; the prompt sweep in a single tmux round trip |
| worktree core | tmux-free snapshots, recovery refs and their expiry, and removal parent cleanup; merge verdicts are tested in `~/dev/gwt` |
| gwt popup | real creation uses caller HEAD, configured root, seeding, and window delivery; the bare first paint shows before a held-back `gwt list` and keeps a query and a mark across the swap; ctrl-y copies through a stub `toclip`; the merged tag and ctrl-g share one eligibility rule, leaving unmerged and locked work; private tmux socket |
| popup overlay | candidate preserves the popup during redraws; stock must reproduce the defect on private sockets ([package runbook](tmux-popup-patch.md)) |
| cout | the installed `cout` binary end to end (or `$COUT_BIN`): command/output pairing across nested shells, indexed copies, recorder retention/cleanup, terminal rendering with the real transient prompt, and `prefix o` leaving no popup; private tmux sockets, a temporary home, and a fake clipboard isolate state, and every store path is checked to lie inside the sandbox before a delete. Parser, store, and replay unit tests are in `~/dev/cout` |
| Claude sessions | shared-store topology and repair, plus launcher routing and workspace effort, against a throwaway `$HOME` |
| startup options | non-interactive `.zshenv` state in a clean `zsh -c` |
| portability | the package starts silent on a bare `$HOME` from an empty environment, loads every module, and loads a host file only from `~/.config/machine`; interactive shells keep `git.zsh`'s `git()` and one fpath whatever they inherit; interactive cases run on a pty |
| theme sync | startup + precmd switching against a throwaway `$HOME` |
| gwt shell | completion, parent-shell entry, configured placement, caller HEAD, seeding, and compatibility shim in a temporary home |
| git wrapper | the branch guard fires on a stale base and follows `gitguard on/off`; under the working tree's `git/.gitconfig`, planlab pushes (clone and worktree) get `repo.pushArgs` and skip the pre-push hook, others run it; local repositories under a temporary home, no user git config, and a check that the live guard marker is untouched |
| cwd guard | deleted-directory recovery without touching the caller |
| Stow reach | root-memory and package-ignore invariants from the working tree |
| bypass guard | dormant hook logic through synthetic PreToolUse payloads |
| skill sync | invocation overrides, refreshed cloud exclusions, runtime metadata recovery, metadata preservation, byte-exact document copies, validation before writes, and symlink destinations; every case runs a copied script with a temporary home, manifests, and sentinel checkout, so scope regressions stay in the sandbox |
| toclip | which clipboard a copy reaches: pbcopy at the screen, the ssh client (not tmux's activity pick) inside tmux, the buffer kept for oversize payloads; private tmux socket, real clients on ptys, a stub pbcopy, and K8 asserts the real clipboard is untouched |
| aws-login | sign out, sign in, verify, then stamp; the device-code flow only on the mini marker; `--status` from the stamp; a stub `aws` on PATH records the calls, a temporary `HOME` holds the stamp, and A8 asserts the real state directory is untouched |
| Claude reply reference | Ctrl+G buffers open the right reply, history and whole-turn views, `:wq` exits with the draft byte-exact, closing either window never strands the editor, the layout follows pane width, lookalike files are ignored; the working tree's full Neovim config against a fixture `CLAUDE_CONFIG_DIR` naming the suite as the claude process, temp XDG state, tmux unset |

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
crosses the sandbox boundary, add the guard alongside it (the chip suite's C9
guards its quota refresher). **Give a spawned side effect a three-way lever,
not an off switch**, in the shape of `CLAUDE_CTX_REFRESH_CMD`: unset means
production, set-but-empty disables the spawn, and set to a path substitutes a
stub. A lever that could only disable would buy isolation by leaving the
trigger, the throttle and the lock permanently unexercised; C22 drives all of
them against the stub.

**Never delete through a path read from state.** A store directory, a pane
option or a manifest field is empty exactly when the thing under test failed,
and `Path("")` is `.`, the process's working directory. On 2026-09-28 a
negative control, the cout suite run against a binary that does nothing,
reached `shutil.rmtree(Path(""))` from the checkout and emptied `~/dotfiles`,
`.git` included. Before a delete, check that the path is non-empty, absolute
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

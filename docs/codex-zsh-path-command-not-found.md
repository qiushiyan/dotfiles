# Codex cannot find a CLI that works in the terminal

Use this runbook when Codex reports `command not found` for an installed tool,
or selects a different Node/package-manager executable from interactive zsh.
The shell startup model lives in [zsh.md](zsh.md).

## Recognize the failure

The Obelisk failure exposed two independent sources of drift:

- pnpm installed `obelisk` under `~/Library/pnpm/bin`, but that directory was
  added only by `.zshrc`. The executing Codex shell was `/bin/zsh` with both
  interactive and login mode off, so it skipped `.zshrc`.
- `codex/.codex/config.toml` supplied a static `PATH` through
  `shell_environment_policy.set`. That copied list omitted pnpm's directory.

Calling Obelisk by absolute path succeeded, including a real index query.
That isolated this failure to command lookup rather than filesystem access
or Obelisk's database permissions.

## Diagnose a recurrence

Run this in both the failing agent shell and a working terminal. Substitute
the affected CLI for `obelisk`:

```zsh
print -r -- "shell=$0 interactive=$options[interactive] login=$options[login]"
print -r -- "ZDOTDIR=${ZDOTDIR:-unset}"
print -rl -- $path
whence -va obelisk node pnpm
```

Compare fresh startup modes without inheriting the terminal's populated PATH:

```zsh
for mode in -c -lc -ic -lic; do
  print -r -- "mode=$mode"
  /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh "$mode" \
    'whence -p obelisk node pnpm'
done
```

If only interactive shells work, inspect `.zshrc` for misplaced tool-path
setup. If login shells select Homebrew's Node, inspect the final startup
ordering. If direct shells work but the agent fails, check Codex's environment
overrides and restart the app to refresh configuration and shell snapshots.
`SHELL=/bin/zsh` alone does not tell you whether `.zshrc` was read.

## Restore the shared setup

1. Add CLI install directories to `zsh/.config/zsh/toolchain.zsh`. `.zshenv`
   sources it for every normal zsh invocation; keep it quiet and usable without
   a terminal. Interactive integrations remain in `.zshrc`.
2. Preserve the reapplication from `.zshrc` and `.zlogin`. Homebrew and macOS
   login profiles can reorder PATH after `.zshenv`; `.zlogin` also covers
   non-interactive `zsh -lc` calls. `~/.zprofile` is machine-local installer
   state, while `.zlogin` belongs to the Stow package.
3. Keep `shell_environment_policy.inherit = "all"` and leave `PATH` out of
   `shell_environment_policy.set`. A second tool-path list in Codex will drift.
4. After adding startup files, run `make restow PACKAGES=zsh` from the dotfiles
   root. Restart Codex after changing its configuration; use `exec zsh` to
   refresh an existing terminal.
5. Repeat the mode probes, then run the affected CLI through the agent using
   its bare command name. Finding an executable verifies lookup; a successful
   real operation verifies that its runtime and permissions work too.

This setup shares installed-tool paths. It does not synchronize exports,
credentials, functions, or virtual environments activated later in another
terminal. A remote agent also needs the setup on its execution host.

## Related reports and references

- [Zsh startup guidance](https://zsh.sourceforge.io/Intro/intro_3.html)
  places command search paths in `.zshenv` and interactive setup in `.zshrc`.
- [Codex environment policy](https://learn.chatgpt.com/docs/config-file/config-advanced#shell-environment-policy)
  controls the initial environment passed to commands; shell startup can
  subsequently change it.
- [Codex issue #20220](https://github.com/openai/codex/issues/20220)
  reports GUI-launched Codex losing PATH through zsh snapshot serialization.
  It is related evidence, not a verified diagnosis of this machine's snapshot.
- [Codex discussion #26901](https://github.com/openai/codex/discussions/26901)
  collects parent-environment, login-profile, daemon, and worktree mismatches.
  Inheriting the parent environment cannot supply paths the GUI parent lacks.

# Bypass-mode cd guard (dormant workaround, kept as a reference implementation)

**Status: dormant — not needed, not deleted.** The Claude Code bug it works
around (2.1.259, unfixed at the last probe) arms only while a `Read(...)` deny
rule is loaded, and planlab's shared settings, the only source that loaded one,
carry none. A deny rule returning in a repo you run `x` sessions in — another
repo, a managed policy, a teammate re-adding one — re-arms the need.

The hook is `claude/.claude/hooks/bypass-cd-read-guard.sh`, registered as a
`PreToolUse` hook on `Bash` in `claude/.claude/settings.json` beside
`block-dangerous-git.sh`. It still runs, but its first executable line exits 0
unless `BYPASS_CD_READ_GUARD_ACTIVE=1`. The guard logic under it is pinned by
`zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh`, which exports that
variable; the hook's header and inline comments own how it decides. Hooks on
one matcher run independently, so `block-dangerous-git.sh` still blocks
`cd X; git push --force`.

## Re-arming it

Do this only when both hold: a `Read(...)` deny rule is loaded in a repo
you run `x` sessions in, AND the "Retiring it" check below still quotes the
"only you can approve" message.

1. In `claude/.claude/hooks/bypass-cd-read-guard.sh`, comment out the
   `[ "${BYPASS_CD_READ_GUARD_ACTIVE:-0}" = "1" ] || { cat >/dev/null; exit 0; }`
   line (or export the variable in the `env` block of
   `claude/.claude/settings.json`).
2. Flip the status paragraph above and the "dormant" wording in `CLAUDE.md`,
   `docs/claude-accounts.md`, `docs/testing.md`, the pointer above
   `CLAUDE_X_BYPASS` in `zsh/.config/zsh/claude.zsh`, and the hook's and the
   suite's headers.
3. Run `zsh zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh`; the
   first case (dormant default) is the one that should then fail — delete it.

The sections below describe the bug and the guard when armed.

## TL;DR

(Behaviour when armed. Unarmed — the current state — every row is
"untouched".)

| Session | Command shape | Result |
|---|---|---|
| bypass (`x`, `x-<email>`, `x-select`) | `cd DIR` then, after a `;`, newline, `\|` or `\|\|`, one of grep, egrep, fgrep, rg, diff, git, cp, mv on a relative path | Refused before Claude Code sees it; the model gets a message saying to drop the `cd` (when it targets the cwd) or re-issue the command as one `&&` chain, and does so |
| bypass | `cd DIR && grep <relative>` (an unbroken `&&` chain), the same readers on absolute paths, or `cd` + `cat`/`ls` | Untouched |
| prompted (`x-account`, plain `claude`) | anything | Untouched — the hook exits 0 on any `permission_mode` other than `bypassPermissions` |

Cost when it fires: one retry. Models drop the habit after the first
message in a session.

## The bug it works around

Claude Code 2.1.259's changelog: *"Fixed Bash `Read()` deny rules not
covering ... `cd DIR && cat FILE` compounds"*. The implementation, read
from the binary, is a check that fires when **all three** hold:

1. any `Read(...)` deny rule is loaded from **any** settings source;
2. the command is one of grep, egrep, fgrep, rg, diff, git, cp, mv;
3. a `cd` appears earlier in the compound, the path operand is relative,
   and the chain from the `cd` to the reader is **not** pure `&&`.

The analyzer follows the working directory through `cd DIR && reader`
and nothing else. Probed on 2.1.259 (hooks disabled, deny `Read(./.env)`,
reading `docs/standards.md`):

| shape | result |
|---|---|
| `cd DIR && grep x rel` | runs |
| `cd DIR; grep x rel` | asks |
| `cd DIR` newline `grep x rel` | asks |
| `cd DIR && grep x rel; grep x rel` | asks (the second grep) |
| `cd DIR && echo x; grep x rel` | asks |
| `cd DIR \| cat; grep x rel` / `cd DIR \|\| exit 1; grep x rel` | asks |

For every "asks" row it skips path resolution entirely and shows:

```
grep on 'docs/x.md' after a cd would search a directory that cannot be
determined here, and a Read() deny rule is configured; only you can approve
running it anyway.
```

Two defects make this a bug rather than a feature: the operand is checked
against *nothing* (a `docs/x.md` that can never match `Read(./.env)` still
asks, and the `cd` target is an absolute literal that the `&&` path already
proves the analyzer can follow), and the ask is human-only — bypass mode surfaces it, a
`PreToolUse` hook returning `permissionDecision: "allow"` does not clear
it, and in `-p` mode it becomes a hard tool error. An unattended `x`
session just stalls on it. Models prefix `cd <cwd>;` to compound commands
habitually (39 of 55 Bash calls in the session that surfaced this), so it
fires several times an hour.

## What was tried and rejected

- **`--setting-sources user,local` on the bypass launchers** silences it by
  not loading project settings, but the project source also carries the
  project's skills, commands, agents, plugins, allow list and `.mcp.json`, so
  an `x` session would lose every project skill.
- **A hook rewriting the command via `updatedInput`** to strip the redundant
  `cd` works, but a stripped `cd` is not provably inert (`OLDPWD`, logical vs
  physical cwd through a symlink, a `cd` that would have failed), the
  transcript would show a command that never ran, and it covers only the
  cwd-targeting shape.

## Retiring it

Dormancy is not retirement: the hook is off because no deny rule is loaded,
not because Claude Code is fixed. Run this on each Claude Code update that
mentions deny rules, Bash path checks, or bypass mode. It costs one small
model call.

```bash
R=$(mktemp -d) && mkdir -p "$R/.claude" "$R/docs" \
  && echo '{"permissions":{"deny":["Read(./.env)"]}}' > "$R/.claude/settings.json" \
  && echo 'spec: hello' > "$R/docs/standards.md" \
  && (cd "$R" && claude -p --dangerously-skip-permissions --model sonnet \
       --settings '{"disableAllHooks":true}' \
       "Call the Bash tool once with the command string below, byte for byte — keep the ';' exactly as given, do not 'improve' it. If the tool errors, do not retry. Reply with the raw tool output or the exact error text.

cd $R; grep -n spec docs/standards.md")
```

`disableAllHooks` takes this hook out of the picture; the `;` is the point
(`&&` already works), and haiku tends to rewrite it to `&&`, hence sonnet
and the wording. If the reply is
`1:spec: hello`, Claude Code resolves the path itself now; if it quotes the
"only you can approve" message, the bug is still there.

When it passes, the reference implementation has nothing left to
reference — delete all of:

1. `claude/.claude/hooks/bypass-cd-read-guard.sh`
2. its entry in `claude/.claude/settings.json` (`hooks.PreToolUse`, the
   `Bash` matcher — leave `block-dangerous-git.sh`)
3. `zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh` and its lines in
   `docs/testing.md`
4. the pointer comment above `CLAUDE_X_BYPASS` in `zsh/.config/zsh/claude.zsh`
   (keep the array)
5. this file, and its lines in `CLAUDE.md` and `docs/claude-accounts.md`

Upstream: the issue to file on anthropics/claude-code is the "Retiring
it" repro plus the two defects above, with the separator table as the
sharpest evidence (the `&&` row proves the directory is trackable); check
the tracker before filing a duplicate.

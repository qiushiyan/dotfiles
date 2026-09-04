# Bypass-mode cd guard (dormant workaround, kept as a reference implementation)

**Status: dormant since 2026-09-03 — not needed, not deleted.** It papers
over a Claude Code bug introduced in 2.1.259 (released 2026-09-02), but the
bug only arms when a `Read(...)` deny rule is loaded, and the one rule set
that reached my sessions is gone: planlab develop commit `6920151d7c`
("drop the Read() deny rules from the shared Claude settings", Andy Shu,
2026-09-03) emptied the project's deny list for the same reason this hook
existed. With no rule loaded, the check never fires and the hook had
nothing left to refuse — it was only costing retries on legitimate
commands. The Claude Code bug itself is NOT fixed (last probed 2.1.259);
the "Retiring it" check below still answers that question.

The hook is still registered and still runs, but its first executable line
is an early `exit 0` gated on `BYPASS_CD_READ_GUARD_ACTIVE=1`; the guard
logic under it is unchanged and the test suite exports that variable so the
reference implementation stays pinned. It is kept rather than deleted
because a Read() deny rule can come back — another repo, a managed policy,
a teammate re-adding one — while Claude Code still has the bug, and the
rewrite is not trivial (see "How the hook decides").

Lives in `claude/.claude/hooks/bypass-cd-read-guard.sh`, registered as a
`PreToolUse` hook on `Bash` in `claude/.claude/settings.json`, beside
`block-dangerous-git.sh`. Pinned by
`zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh`.

## Re-arming it

Do this only when both hold: a `Read(...)` deny rule is loaded in a repo
you run `x` sessions in, AND the "Retiring it" check below still quotes the
"only you can approve" message.

1. In `claude/.claude/hooks/bypass-cd-read-guard.sh`, comment out the
   `[ "${BYPASS_CD_READ_GUARD_ACTIVE:-0}" = "1" ] || { cat >/dev/null; exit 0; }`
   line (or export the variable in the `env` block of
   `claude/.claude/settings.json`).
2. Flip the status paragraph above and the "dormant" wording in `CLAUDE.md`,
   `docs/claude-accounts.md`, `docs/testing.md` and the
   `zsh/.config/zsh/claude.zsh` header back.
3. Run `zsh zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh`; the
   first case (dormant default) is the one that should then fail — delete it.

Everything below is written as of when the hook was live; it describes the
bug and the guard as built.

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

1. any `Read(...)` deny rule is loaded from **any** settings source — the
   planlab repo committed `Read(./.env)` and friends in its project
   `.claude/settings.json` until `6920151d7c`, so every worktree of it
   qualified;
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
fired several times an hour.

## What was tried and rejected

| Option | Why not |
|---|---|
| `--setting-sources user,local` on the bypass launchers | Silences it (project settings never load, so no `Read()` rule), but the project *source* also carries the project's `.claude/skills/`, `.claude/commands/`, agents, plugins, allow list and `.mcp.json`: an `x` session then loses every project skill (verified: `add-theme` vanishes from the startup manifest; `/` completion shows global skills only), a different world from every other Claude Code session on the repo. It was live in `claude.zsh` for ~20 min on 2026-09-03; shells that sourced the file then kept the flag until `exec zsh` |
| `PreToolUse` hook returning `allow` | Does not clear this check (verified) |
| `PreToolUse` hook rewriting the command via `updatedInput` to strip the redundant `cd` | Works, but a stripped `cd` is not provably inert (`OLDPWD`, logical vs physical cwd through a symlink, a `cd` that would have failed), the transcript would show a command that never ran, and it only covers the cwd-targeting shape |
| Dropping the `Read()` rules from planlab's settings | Rejected at the time (team file; the rules protect prompted sessions) — then done by the team itself in `6920151d7c` on 2026-09-03, which is what made this hook dormant |
| Pinning Claude Code to 2.1.258 | Stopgap that fights the auto-updater |
| Telling the model not to `cd` in CLAUDE.md | The system prompt already says so; it does it anyway |

The deny-and-instruct shape was codex's recommendation in a consult round
(`~/.local/state/envoy/jobs/dotfiles-4f711dad/20260903-105647-consult`).

## How the hook decides

Heuristic, not a parser; it leans toward refusing, because a false positive
costs a retry and a false negative costs a stalled session.

- Gate: `permission_mode == "bypassPermissions"` from the hook payload.
  Fast exit when the command has no `cd` word.
- Heredoc bodies are dropped, then the command is split into simple
  commands on `; && || | & ( )` and newlines with a quote-aware tokenizer
  (`shlex`, punctuation mode), so a `;` inside a commit message or a
  quoted prompt never opens a segment. A redirect's target is skipped.
- Each segment remembers the separator before it. Once a `cd` has been
  seen and any later separator is not `&&` (a line break counts as `;`),
  the chain is broken; the first segment after that whose executable is a
  guarded reader and has an operand that is not a flag, not absolute, not
  `~`- or `$`-prefixed, is refused. A pure `&&` chain passes through. grep-family skips
  the pattern operand (unless `-e`/`-f` supplied it); git only counts
  pathspecs after `--`, or words that look like paths, excluding `-m`
  values.
- Anything it cannot parse (an unbalanced quote across lines, a Python
  error) passes through: fail open, never a broken command.

Hooks on the same matcher run independently, so `block-dangerous-git.sh`
still reads the original command; `cd X; git push --force` stays blocked
by it (pinned in the suite).

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
3. `zsh/.config/zsh/tests/bypass-cd-read-guard.test.zsh` and its line in
   `docs/testing.md`
4. the `CLAUDE_X_BYPASS` header paragraph in `zsh/.config/zsh/claude.zsh`
   that points here (keep the array)
5. this file, and its lines in `CLAUDE.md` and `docs/claude-accounts.md`

Upstream: the issue to file on anthropics/claude-code is the "Retiring
it" repro plus the two defects above, with the separator table as the
sharpest evidence (the `&&` row proves the directory is trackable); check
the tracker before filing a duplicate.

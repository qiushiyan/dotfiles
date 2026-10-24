# Moving an existing CLI onto clikit

The tool already has callers: shell wrappers, tmux scripts, skills, other
tools. The migration is done when, for every invocation those callers use, the
old and new binaries print the same bytes and exit with the same codes, except
for changes you have listed and the user has approved, and every help page is
clikit's. The order below matters: each step is what makes the next one
checkable.

1. **Find the callers.** Search the other repositories (`~/dotfiles`, the
   skills, other `~/dev` tools) for the tool's name, or run the project's own
   consumer search where it has one. Each invocation shape found is a case for
   step 2, and each caller that parses stderr or an exit code is a caller to
   update in step 6.
2. **Pin today's behaviour before touching the grammar.** Run the old binary
   over fixtures in a temporary home and record stdout, stderr and the exit
   code for every case. A test replays them against the code being changed.
   Give these pins their own update switch, apart from `make golden`, so
   accepting a help-page change can never rewrite a contract. The two built
   so far: `~/dev/brief/cmd/brief/compat_test.go` and
   `~/dev/claude-steps/cmd/claude-steps/contract_test.go`.
3. **Map the exit codes.** List what each code means today. clikit's usage
   code defaults to 2. Where 2 already means something else (brief's
   ambiguity), set `App.UsageCode` to the tool's existing usage code. A
   failure that prints an error and has its own code becomes
   `clikit.Fail(n, err)`.
4. **Move the domain logic, then switch the grammar**, as separate commits.
   The pinned suite replays byte-identical across the move out of `cmd/`
   before any parsing changes, so a difference after the switch belongs to
   the switch.
5. **Split the old usage text across the pages it explains.** A command's own
   prose goes in its `Help()`. A section every page needs goes on the root as
   `Shared`; one that serves only some commands is returned by those
   commands. Lines that list flags, defaults or synopses are dropped, since
   help generates them. Then give a fresh agent nothing but the help pages
   and a handful of real tasks, and fix what it gets wrong.
6. **Record every difference callers can see**: clikit's help pages, the
   `<tool>: error:` line, argv the old parser silently accepted and Kong now
   refuses, or the reverse. Record them wherever the project keeps
   compatibility decisions, and update each caller that read the old format
   (brief's zsh completer stripped `brief: ` from error lines).

Where a hand-written parser and Kong disagree:

- **A list flag that takes values up to the next flag** (`--paths a b`) parses
  as one value plus a positional under a Kong slice: write a mapper (SKILL.md,
  less common forms).
- **A bare `tool`, or `tool <word>` falling through to one command**:
  `default:"withargs"` on that command.
- **Top-level modes** (`--json`, `--all`) that subcommands also accept: a root
  flag cannot share a name with a subcommand's, so the modes live on the
  default command.
- **Free text that starts with a dash** needs `--` before it. clikit's error
  says so, but a caller that relied on the old parser letting it through has
  to change.

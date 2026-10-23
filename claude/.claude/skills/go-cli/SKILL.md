---
name: go-cli
description: Conventions for building or changing a personal Go CLI in ~/dev — project shape, clikit commands and help, tests, Go 1.27, module design, performance traps.
disable-model-invocation: true
argument-hint: "[the tool or change to build]"
---

# Personal Go CLIs

You are turning a settled design into a Go command-line tool in `~/dev`, or
changing one that exists. These tools are used by agents as much as by the
user: skills tell an agent to run `<tool> --help` and to read its `--json`
output, so the help pages and the output contract are the tool's
documentation. The work is done when `make check` passes, every help page
reads correctly to an agent that has never seen the tool, and `make install`
has put the binary where callers find it.

## Project shape

```
<tool>/
  cmd/<tool>/main.go   the clikit App, the command structs, main
  internal/<domain>/   the work: plain Go taking values, an io.Writer, a context
  testdata/help/       golden help pages (make golden rewrites them)
  Makefile             build, install, test, check, golden
  AGENTS.md            CLAUDE.md is a symlink to it
  README.md            what the tool is for, how to use it, its design
```

- **Module** `github.com/qiushiyan/<tool>`, created with `go mod init`, then
  `go mod edit -go=1.27.0` and `go get github.com/qiushiyan/clikit@latest`.
- **Dependencies**: the standard library, plus clikit and Kong for the command
  line. Any other module earns its place by an API the standard library lacks
  (`BurntSushi/toml` and `golang.org/x/term` have); a few lines of our own beat
  a dependency.
- **Makefile**: `install` builds beside the target and renames into place,
  because agents and tmux call the binary by path and must never run a
  half-written file. `check` runs vet, `go fix -diff` (must print nothing) and
  `go test -race ./...`. Copy the targets from `~/dev/clikit/Makefile` and
  `~/dev/gwt/Makefile`.
- **AGENTS.md** carries what the code cannot show: the contracts other
  repositories depend on (output, exit codes, flags, files they read), how
  tests isolate live state, and that callers stay on the old binary until
  `make install`. Read `~/dev/gwt/agents.md` and `~/dev/claude-steps/AGENTS.md`
  for the shape.
- **Both machines**: register the repository and the tool for the mini as
  `~/dotfiles/docs/twin.md` describes, before anything relies on the tool.

## Commands with clikit

clikit (`~/dev/clikit`, `github.com/qiushiyan/clikit`) runs a Kong grammar
and owns the parts every tool shares: help that always works, help rendered
from the declaration, exit codes, and tests through the same entry point.
Declare each command once, as a Kong struct; its usage line, flag list,
defaults and constraints in help are generated from that declaration.

```go
type CLI struct {
	Dir  string `help:"Directory that holds notes.json." env:"JOT_DIR" default:"~/.jot" type:"path"`
	JSON bool   `help:"Print JSON instead of text."`

	Version kong.VersionFlag `help:"Print the version and exit."`

	Add    AddCmd    `cmd:"" help:"Add a note."`
	List   ListCmd   `cmd:"" aliases:"ls" help:"List notes, newest first."`
	Export ExportCmd `cmd:"" help:"Write every note to a file or stdout."`
}

type AddCmd struct {
	Text []string `arg:"" help:"Words of the note; a single - reads it from stdin."`
	Tag  []string `short:"t" help:"Tag the note; repeat for more tags."`
}

func (c *AddCmd) Run(ctx *kong.Context, cli *CLI, s *Store, stdin io.Reader) error { ... }

var app = clikit.App{
	Name:        "jot",
	Description: "jot keeps short notes in one JSON file.",
	New:         func() any { return &CLI{} },
	Options: []kong.Option{
		kong.Vars{"version": "0.1.0"},
		kong.BindToProvider(func(cli *CLI) (*Store, error) { return openStore(cli.Dir) }),
	},
	ExitCodes: map[int]string{3: "a note id does not exist"},
}

func main() { os.Exit(app.Run(os.Args[1:])) }
```

- **Global flags** are fields on the root struct. A Run method or provider
  that needs them takes the root (`cli *CLI`); Kong binds it. Options are
  shared by every run, so they never capture a grammar instance
  (`kong.Bind(&cli.Globals)` carries one run's values into the next).
- **Dependencies load lazily** through `kong.BindToProvider`, called only when
  a Run method asks for the value. Config, tokens and stores loaded anywhere
  earlier would make `--help` fail on a broken config.
- **Output** goes to `ctx.Stdout`, errors and progress to `ctx.Stderr`, input
  comes from an `io.Reader` parameter. These are the App's writers, so tests
  capture them; `os.Stdout` directly escapes the tests.
- **Statuses**: return an error for a failure; Run prints it as
  `<tool>: error: <err>` and exits 1, so the command prints nothing itself.
  A status of the tool's own is `clikit.Exit(n)` after the command has
  reported it, declared in `App.ExitCodes` so help lists it. A rule the tags
  cannot express (one flag only valid with another's value) is
  `clikit.Usage(err)`, returned before anything changed.
- **Constraints belong in tags**, where help states them: `enum:""` with a
  `default:""` among its values, `xor:"g"` (mark every member `required:""`
  for exactly one), `and:"g"`, `env:""`, `type:"existingdir"`.
- **Long help**: `Help() string` on a command holds the prose an agent needs
  to use it (what it does, side effects, output shape); `HelpSections()`
  adds titled blocks such as Examples, with `Shared: true` for one that
  belongs on every page below. Both print verbatim.
- **Less common forms**: a default subcommand (`default:"withargs"`),
  passthrough to a child program (`arg:"" passthrough:""`, which keeps `--`),
  hidden internal commands (`hidden:""`).

clikit rejects a declaration whose help would be missing or untrue, so the
first test names every flag without help. The full contract is
`~/dev/clikit/doc.go`; `~/dev/clikit/run_test.go` exercises every grammar form
above; Kong's tags are in its README (`find-docs` with `/alecthomas/kong`).

## Help and output are the interface

- Write every help tag, `Help()` and section to
  `../prompt-engineering/SKILL.md`: the reader is a model holding nothing but
  the page. Say what the flag does and why someone would pass it; the
  synopsis, defaults, allowed values and env vars are generated, so prose
  that repeats them only drifts.
- `--json` prints one JSON document on stdout and nothing else; text mode is
  for people. A shape other repositories parse is a contract: pin it in a
  test and name its consumers in AGENTS.md.
- An error line names what failed and the next action, in one line.

## Tests

- Run the tool through the App, exactly as main does:
  `clikittest.Run(app, "add", "milk")` returns the code, stdout and stderr.
  Copy the App to set `Stdin`; set environment with `t.Setenv`.
- `clikittest.Golden(t, app, "testdata/help")` pins every help page and
  reports stale ones; `make golden` (`CLIKIT_UPDATE=1 go test ./...`) accepts
  an intended change, and the diff is reviewed like code.
- Tests never touch live state: a temporary `HOME`, temporary repositories
  and config, stub `gh`/`git`/`tmux` binaries on a `PATH` without the real
  ones, a private tmux socket (`tmux -L <name>`), no network.
- Domain packages under `internal/` are tested directly, without the CLI.

## Writing Go on 1.27

Training data is mostly pre-1.21 Go, so the reflex is a hand-rolled loop
where the standard library now has a call. Read `GO-1.27.md` beside this file
before writing, and close every change on the gate:

```
go fix -diff ./...    # prints nothing; apply with go fix ./... and repeat to a fixpoint
go vet ./...
go test -race ./...
```

What only 1.27 has, so no model knows it unprompted:

- `uuid` is in the standard library: `uuid.NewV7()`, `uuid.Parse`.
- `encoding/json` is backed by json/v2 (same semantics, faster unmarshal,
  different error text); `encoding/json/v2` and `encoding/json/jsontext` are
  importable for stricter defaults and token-level reads.
- Generic methods: a method may declare its own type parameters (interface
  methods still cannot).
- A struct literal may set a promoted field directly: `T{X: 1}` for
  `T{U: U{X: 1}}`.
- `strings.CutLast` / `bytes.CutLast`; `testing/synctest.Sleep`; the
  `goroutineleak` profile in `runtime/pprof`; macOS 13 is the floor.

## Module design

- `cmd/<tool>` only translates: flags in, one call into `internal/`, output
  out. A domain package that imports `kong` or reads `os.Args` cannot be
  tested or reused without the CLI.
- Each invariant has one owning package, and every caller goes through it:
  one decoder for a file format, one function that decides "matches". A
  second implementation in another package is how two readers come to
  disagree. `~/.config/lessons/codebase-design/deep-modules.md` has the
  vocabulary.
- An interface is declared by the package that consumes it, when a second
  implementation exists (often a test fake), never ahead of one.
- Shelling out to `git`, `gh` or `tmux` is the cost and the failure surface
  in most of these tools: go through one small package that runs the command,
  checks its exit status and returns stderr in the error.

## Performance traps

A CLI's hot path is often its start: tmux status lines and prompts run these
binaries every few seconds.

- **Startup.** Package-level work and every imported package's `init` run on
  each call, `--help` included. `GODEBUG=inittrace=1 <tool> --help` prints the
  cost per package; keep heavy setup inside the command that needs it.
- **Subprocesses** dominate when a tool runs one git command per item. Ask
  git once for all of them (`git for-each-ref --format`, `git worktree list
  --porcelain`), and run independent commands concurrently with
  `sync.WaitGroup.Go`.
- **Unbuffered stdout.** In production `ctx.Stdout` is `os.Stdout`, which
  makes a write syscall per `Fprintf`. Wrap large output in a `bufio.Writer`
  over `ctx.Stdout` and check the error from `Flush`.
- **Long lines.** `bufio.Scanner` fails with "token too long" past 64 KiB, and
  one line of a Claude transcript can run to hundreds of KiB. Raise the limit
  with `scanner.Buffer`, or read with `bufio.Reader.ReadBytes('\n')`.
- **Retained memory.** A substring or subslice keeps its whole source alive;
  `strings.Clone` the small pieces kept from a large file.
- **Directory walks.** `filepath.WalkDir` avoids the `Lstat` per entry that
  `filepath.Walk` pays.

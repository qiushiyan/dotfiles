---
name: go-1.27-changes
description: What changes when a Go project lands on 1.27 — the toolchain gate, the stdlib that replaces hand-rolled code, and the rewrites to overrule.
disable-model-invocation: true
argument-hint: "optional: the module to work in — defaults to the current one"
---

# Landing on Go 1.27

Two jobs here. **Upgrading** a module runs the gate, then works the overrules.
**Writing** Go on 1.27 reads the stale → current tables first, so the draft is
already current and the gate has nothing to say.

Model-default Go is stale: training data is dominated by pre-1.21 code, so the
reflex is a hand-rolled loop where a stdlib call now exists. `go fix` holds the
authoritative list of rewrites. This file adds what it does not print — when each
idiom landed, what only 1.27 has, and the handful of rewrites to overrule.

## Turning 1.27 on

```
go mod edit -go=1.27.0     # or: go mod init <path> && go mod edit -go=1.27.0
go mod tidy
```

The `go` directive is the switch. It gates language features and vet behaviour,
and under the default `GOTOOLCHAIN=auto` it also makes the go command fetch that
toolchain on demand — so the module builds on 1.27 even when the installed `go`
is older, and a package manager lagging behind the release is no reason to wait.

That leaves one gap: `go` invoked **outside** a module — `go install x@latest`,
gopls, a scratch `go run` — still uses the installed toolchain. Close it by
pinning a floor, which reuses the already-fetched toolchain and downloads nothing:

```
go env -w GOTOOLCHAIN=go1.27.0+auto
```

`+auto` keeps 1.27.0 as a floor rather than a ceiling: a module requiring newer
still upgrades. Reset with `GOTOOLCHAIN=auto` once the installed go catches up.

`go mod tidy` on a 1.27 module also enforces a two-block require layout — direct,
then indirect — and re-classifies dependencies that were mislabelled `// indirect`.

## The gate

Every Go change closes on this, in order:

```
go fix -diff ./...    # must print nothing
go vet ./...
go test ./...
```

`go fix -diff` prints a unified diff of every stale idiom it can rewrite, and
changes no files. Nothing printed is the completion bar — not "it compiles".

**Run it to a fixpoint.** One rewrite exposes the next, so a clean pass is not
guaranteed after the first apply. A double clamp is the common case: `min(...)`
followed by a trailing `if x < 0 { x = 0 }` only collapses to `max(min(...), 0)`
on the second pass, because the first pass is what creates the `min` call. Loop
`go fix ./...` and `go fix -diff ./...` until the diff is empty.

Read each diff before keeping it, and work the **overrules** below. To apply a
subset, name analyzers with `-NAME`: `go fix -waitgroupgo -rangeint ./...`. Full
registry and per-analyzer docs: `go tool fix help` and `go tool fix help <name>`.

`go test` on a 1.27 module now runs the `stdversion` vet check by default, which
reports stdlib symbols newer than the file's effective go version.

## Stale → current

The version marks when the replacement landed — roughly why the reflex is stale.
Rows marked ⚠ need a human call; see **Overrule these**.

### Loops, slices, maps

| Stale | Current | |
|---|---|---|
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| `for i := len(s)-1; i >= 0; i--` | `for _, v := range slices.Backward(s)` | 1.23 |
| `for _, v := range s { if v == x { return true } }` | `slices.Contains(s, x)` | 1.21 |
| `sort.Slice(s, func(i, j int) bool {...})` | `slices.Sort(s)` (basic types) | 1.21 |
| `for k, v := range src { dst[k] = v }` | `maps.Copy` / `maps.Clone` ⚠ | 1.23 |
| `for i := 0; i < x.Len(); i++ { use(x.At(i)) }` | `for e := range x.All()` | 1.23 |
| `for _, x := range s { x := x; ... }` | drop the `x := x` | 1.22 |

### Strings

| Stale | Current | |
|---|---|---|
| `for _, ln := range strings.Split(s, "\n")` | `for ln := range strings.SplitSeq(s, "\n")` | 1.24 |
| `for _, f := range strings.Fields(s)` | `for f := range strings.FieldsSeq(s)` | 1.24 |
| `strings.Index` + slicing | `before, after, ok := strings.Cut(s, sep)` | 1.18 |
| `strings.LastIndex` + slicing | `before, after, ok := strings.CutLast(s, sep)` | **1.27** |
| `if strings.HasPrefix(s, p) { s = strings.TrimPrefix(s, p) }` | `if after, ok := strings.CutPrefix(s, p); ok` | 1.20 |
| `s += x` in a loop | `strings.Builder` | 1.10 |

`bytes` carries the same `Cut` / `CutLast` / `CutPrefix` set.

### Types, errors, tests

| Stale | Current | |
|---|---|---|
| `interface{}` | `any` | 1.18 |
| `if a < b { m = a } else { m = b }` | `min(a, b)` / `max(a, b)` ⚠ | 1.21 |
| `func p[T any](v T) *T { return &v }` then `p(x)` | `new(x)` ⚠ | 1.26 |
| `reflect.TypeOf(uint32(0))` | `reflect.TypeFor[uint32]()` | 1.22 |
| `ctx, cancel := context.WithCancel(context.Background())` + `defer cancel()` | `ctx := t.Context()` | 1.24 |
| `json:",omitempty"` on a **struct-typed** field | `json:",omitzero"` ⚠ | 1.24 |

### Concurrency

`sync.WaitGroup.Go` (1.25) replaces the Add/go/Done dance:

```go
// stale
wg.Add(1)
go func() {
	defer wg.Done()
	work()
}()

// current
wg.Go(func() {
	work()
})
```

`sync/atomic` typed values (1.19) replace the free functions — they make
non-atomic access impossible and fix 32-bit alignment:

```go
var x int32; atomic.AddInt32(&x, 1)   // stale
var x atomic.Int32; x.Add(1)          // current
```

`errors.AsType[T]` (1.26) replaces the out-parameter form of `errors.As`:

```go
// stale
var myErr *MyErr
if errors.As(err, &myErr) { handle(myErr) }

// current
if myErr, ok := errors.AsType[*MyErr](err); ok { handle(myErr) }
```

## Only in 1.27

What no pre-1.27 training data contains:

- **`uuid` is in the standard library.** `uuid.New()`, `NewV4()`, `NewV7()`,
  `Parse`, `MustParse`; `UUID` is a comparable `[16]byte` with `String()`.
  Generate UUIDs with it, and let a third-party uuid module earn its place only
  by an API this one lacks.
- **`encoding/json` is backed by json/v2.** v1 semantics are preserved and no
  migration is required; unmarshal is significantly faster. Error message *text*
  may differ, so tests asserting on JSON error strings can break.
  `encoding/json/v2` and `encoding/json/jsontext` are importable directly for
  stricter defaults and token-level processing.
- **Generic methods.** A method may declare its own type parameters. Interface
  methods still may not, and cannot be satisfied by generic methods.
- **Struct literals accept any valid field selector as a key**, so a promoted
  field is set directly: `T{U: U{X: 1}}` becomes `T{X: 1}`.
- **`strings.CutLast` / `bytes.CutLast`**, `math/big.Int.Divide`,
  `net/url.URL.Clone`, `hash/maphash.Hasher`, `crypto/mldsa` (post-quantum).
- **`testing/synctest.Sleep`** combines `time.Sleep` and `synctest.Wait`;
  `httptest.NewTestServer` gives a server on an in-memory network that works
  under `synctest`.
- **Goroutine leak profile** is GA — `goroutineleak` in `runtime/pprof`, and
  `/debug/pprof/goroutineleak` via `net/http/pprof`. Worth wiring into tests for
  anything with a concurrent fan-out.
- **macOS 13 Ventura is the floor** for darwin binaries. Say so in the release
  notes of anything shipping macOS builds.

## Overrule these

Everything in the registry not named here is a safe mechanical rewrite. These
four need a human call:

- **`minmax` strands trailing comments.** `n := (h-5)/2 // note` becomes a
  three-line `max(` call with the comment sitting between the arguments. Keep the
  rewrite, move the comment back to the end of the line.
- **`newexpr` retires a named helper.** It marks a `Ptr[T]`-style function
  `//go:fix inline` and expands every call site to `new(expr)`. Correct, but it is
  a whole-codebase diff that deletes an API — decide it on its own rather than
  letting it ride along with the rest.
- **`omitzero` changes the wire format.** `omitempty` is a no-op on struct fields,
  which is why it needs replacing, but `omitzero` genuinely starts omitting the
  field — confirm no consumer depends on it always being present.
- **`maps.Clone` preserves nilness.** A nil source clones to nil, not to an empty
  map. Check the caller before swapping a copy loop for it.

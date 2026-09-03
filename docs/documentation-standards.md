# Documentation standards

Write for a smart model that will inspect the repository. Documentation carries
the **mental model**: ownership, boundaries, invariants, decisions, and traps the
environment cannot reveal. Code, config, directory listings, and `--help` own
their inventories.

## Shape

- **Spine first.** A first-read document keeps the vocabulary, workflow, and
  load-bearing constraints. Mechanism used by one branch moves to a satellite.
- **One home per meaning.** A summary may point to its owner; it does not retell
  the mechanism. Change the owner once, then follow its inbound pointers.
- **Patterns over tours.** Prefer compact relationships an agent can execute:

  ```text
  symptom → owner → invariant → check
  stale Codex pane path → codex/.codex/config.toml [tui] → narrow panes shed stable fields first
                         → open Codex in a half- and quarter-width pane
  ```

- **Present state.** Git holds the journey. Design docs say what is true now;
  proposals say what is unbuilt. When a proposal ships, distill its surviving
  decisions into the design owner and delete it.
- **Current names.** Use repo-root-relative paths and real searchable nouns.
  Point at source with a line-sized description; leave signatures and complete
  option lists in source.

## Hot path

The hot path is paid before a session chooses its work:

1. root `CLAUDE.md` / `AGENTS.md`;
2. a package-local instruction file while working in that package;
3. the landing page a root pointer tells the reader to open first.

Hot prose earns its bytes by preventing a wrong edit. Keep conclusions and
pointers there; put proof, recovery detail, and edge cases on demand. Measure a
changed hot document by section. A section that becomes mostly mechanism is a
split candidate even when the whole file is small.

The approximate first-read budget is **100 KB (`wc -c`)**. This repo has no
mandatory onboarding set, so report the unconditional root cost separately from
package-local and landing-page costs.

## What earns documentation

- a cross-package flow or ownership boundary;
- an invariant whose violation damages live state;
- a non-obvious decision and the alternative it beats;
- an operational sequence a filename or command cannot supply;
- evidence needed to reproduce or retire a workaround.

Use a compact rule before prose. Examples:

```text
Codex status: config.toml owns fields; tmux owns only the border presentation.
Test isolation: suite socket + throwaway HOME + guard case.
Stow safety: real target directory → per-item links; absent directory → dangerous fold.
```

Implementation inventories do not earn a cache. In particular:

- name a test suite's responsibility, not its ordinal place in a list;
- name the few config surfaces that form a boundary, not every option;
- avoid live counts unless the number is itself the invariant;
- keep exact commands in runbooks, not in architecture summaries.

## Document roles

- **Design:** present-tense model and invariants; edited in place.
- **Runbook:** ordered actions with a checkable result; exact commands allowed.
- **Proposal/roadmap:** explicitly unbuilt work and open decisions.
- **Evidence/status:** dated observations whose date changes their meaning.
- **Index:** a curated route, not a directory dump.

Dated `specs/`, `plans/`, `records/`, and `researches/` are evidence. They never
serve as a live design dependency. Delete shipped plans after their durable
decisions have an owner; retain a record only while a live retirement or
reproduction check needs it.

## Protected set

These deliberate echoes survive distillation:

- the three red-line summaries in root `CLAUDE.md`; their details live in
  `docs/stow-layout.md` and `docs/testing.md`;
- short user-facing behavior summaries and the cheat sheet in
  `tmux/.config/tmux/workflow.md`; design mechanics live in satellites;
- dated measurements in `docs/ghostty-fonts.md`, the Mac mini status snapshot,
  and temporary workaround status/retirement probes;
- short suite commands in `docs/testing.md` and exact commands in migration or
  recovery runbooks.

Protection covers the meaning, not accumulated narration. Evidence stays dated;
the live conclusion before it stays concise.

## Verification

For every documentation change:

1. Re-read each modified document as one narrative.
2. Resolve every moved basename, heading, and repo-relative path.
3. Grep live docs for deleted proposal paths and superseded terms.
4. Compare status claims with their owning config or executable path.
5. Measure hot sections and the whole tree separately.
6. Confirm the protected set still states the same constraints.

For recurring rot, strengthen the check rather than restating the rule:

- live docs must not route to `docs/**/specs/` or `docs/**/plans/`;
- an early feature-disable gate must be reflected in its workflow and design doc;
- test documentation must not identify suites as “first”, “eighth”, and so on.

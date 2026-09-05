# Documentation standards

Write for a smart model that will inspect the repository. Documentation carries the **mental model** — ownership, boundaries, invariants, decisions, and the traps the environment cannot reveal; code, config, directory listings and `--help` own their inventories. These standards govern the dotfiles repository's docs (`~/dotfiles`) and are the fallback for any project without a `documentation-standards.md` of its own: `/update-docs` and `/distill-docs` read them before editing. A project's own standards win where they exist.

## Documentation shape

Each kind of content has one job, and a doc is one kind:

- **Design docs** say what is true today — present tense, edited in place. When a proposal ships, its surviving decisions fold in here and the proposal is deleted, so no two docs describe one subsystem. Docs lead, code follows: a doc/code disagreement is a doc bug or a design regression, resolved explicitly, never by silently matching either side.
- **Runbooks** are ordered actions with a checkable result; exact commands live here, not in a design summary.
- **Proposals** (`specs/`, `plans/`, roadmaps) are explicitly unbuilt work and open decisions; a live doc cites one as a proposal, and depends on none.
- **Status pages hold only the open ledger** — one per active initiative, and status lives only there: the facts that move with a rollout, the dated items whose follow-up read is still owed, and the owed list. An item enters while it carries an owed read and leaves when the read lands; a landed change that owes nothing leaves its trace in the spec or issue record it shipped with. A page therefore only shrinks between landings; one with a paragraph per event is the smell, and it is what gets read whole at every pickup.

  ```markdown
  - **<date> — <what is now true> (#PR, merged <date> as <sha>).** <one sentence>.
    As-built: <doc § heading>. Records: <issue or spec>. **Closing read owed** —
    ready when: <observable condition — a serving sha, an elapsed window, the first
    qualifying event>. Read: <predicate>.
  ```

  The condition lets a later session take the read without the writer's memory; the landed block (predicate · window · result · verdict · follow-on) replaces the spec's `## Owed` line or closes the issue record, and the item leaves.
- **Evidence tiers** (`specs/`, `issues/`, `records/`, `research/`) are reference behind settled decisions: dated filenames (`YYYY-MM-DD-kebab-name.md`), deleted only after distilling, edited after merge only for a spec's marks (§ As built; the `## Owed` line replaced; the status header when a later spec overturns it). The filename is the index entry, nothing keeps a roster, and an item earns prominence by citation from the live doc where its lesson applies.
- **An index** is a curated route, and every live doc is reachable from it: an unrouted doc is invisible to readers and to a diff-scoped update, and rots.

**A live initiative** — a tree for a system that is partly built — keeps status, proposal and present apart: the README header is the one status home and carries a standing **What is live** block naming, per module doc, the sections that describe running code; module docs are present tense for what runs; what does not run yet is a slice's spec, folded in at merge. Epistemic state (chosen, disputed, superseded) lives in a decisions ledger, delivery state (unbuilt, serving, verified) in the header. A number or heading is an address once cited: numbering never shifts, and a superseded entry keeps its number with a pointer to its successor.

## The hot path

The hot path is what a session pays before it chooses its work: the root `CLAUDE.md` / `AGENTS.md`, a package-local instruction file while working there, and the landing page a root pointer names first. Hot prose earns its bytes by preventing a wrong edit: conclusions and pointers there, proof and recovery detail on demand. The first-read budget is about **100 KB** (`wc -c`); measure a changed hot document by section, and a section that became mostly mechanism is a split candidate however small the file.

**Spine first, one home per meaning.** A first-read document keeps the vocabulary, the workflow and the load-bearing constraints; mechanism used by one branch of work moves to a satellite the spine names. A summary may point at its owner; it does not retell the mechanism. **A section answers one question, and a fact is findable by the question that needs it**, so a session reads to the depth of its question and never the whole file to be safe; a section that grew to hold several families is split by family once they stop churning.

## What earns documentation

A cross-package flow or ownership boundary; an invariant whose violation damages live state; a non-obvious decision and the alternative it beats; an operational sequence a filename or command cannot supply; the evidence needed to reproduce or retire a workaround. Prefer a compact relationship an agent can execute over a tour:

```text
symptom → owner → invariant → check
a run dies at claim time → the claim loop's deadline → a claim defers, it never blocks
                          → grep the journal for the deferral reason
```

Inventories do not earn a cache: name a suite's responsibility rather than its ordinal, the few config surfaces that form a boundary rather than every option, and a count only where the number is itself the invariant. A directory tree is a mental-model device — indented under the directory name, inline comments, naming what a reader must know exists — and a file add or rename does not earn a tree edit. A table is earned only when rows cross two or more axes a reader compares cell-wise. A **lessons entry** is a seam guard, not a story: the invariant (bold, one sentence), the hazard in the present tense, the guard that pins it (a test or symbol), the record that bought it — and one line pointing at the test when a named test already pins it.

## Writing standards

- **Present state.** Git holds the journey; a live doc has no "added X", "as of Y". The diff leaks in with a present-tense disguise — "B, not A", "replaces A", "no longer" — every word true, the sentence shaped like the change. The **future-need test** for any trace of the before-state: will a reader who never saw A need it? Usually not; A earns a mention only while it still bites today, stated as a present hazard, or while a transition is mid-flight.
- **Current names.** Repo-root-relative paths and real searchable nouns; point at source with a line-sized description and leave signatures and option lists in source. Planned or unproven behaviour is marked (a status line, a spec, an open question), never stated as fact.
- Every edit re-reads the whole doc, merges overlap instead of adding a second description, folds new information into the section it belongs in, and cuts what drifted into implementation detail — a doc that gains ten lines should usually shed five.

## When docs need updating

- **None** — bug fixes, internal refactors, tests, dependency bumps.
- **Module-level** — a new function, flow or option inside an existing subsystem: the one doc that owns it.
- **Architecture-level** — a new subsystem, boundary, integration or policy: the index, possibly a new doc, the status page's owed read, a proposal distilled — and the doc *structure* reconsidered, not a wording patch at the point of change.

## Before you commit a doc change

Each rule above still gets broken, because the violation is invisible at the point of writing. Stage first (`git add -A`) so a new doc is diffed too, then:

```bash
# every `<doc>.md § Heading` you touched, or that names a doc you renamed in, resolves
grep -rn '§ <the heading>' --include='*.md' . ; grep -n '^#\+ <the heading>' <the cited doc>

# no cardinal number entered a live doc ("three" → "four" is not the fix; name the members)
git diff --cached -- '*.md' | grep -nE '^\+.*\b(two|three|four|five|six|seven) [a-z]+'

# no changelog disguise entered a live doc
git diff --cached -U0 -- '*.md' | grep -E '^\+[^+]' \
  | grep -nE 'no longer|previously|used to|formerly|before this|was replaced|is now'

# no PR number, date-as-narrative or confidence boilerplate entered a design doc
git diff --cached -U0 -- 'docs/*.md' 'CLAUDE.md' | grep -E '^\+[^+]' | grep -nE '#[0-9]{3,}\b|\b(since|as of|on) 20[0-9]{2}-'

# no live doc routes to a proposal
git grep -nE 'docs/[^ )]*/(specs|plans)/' -- 'docs/*.md' 'CLAUDE.md'

# a status page holds only open items: every dated item carries an owed read (skip where the tree has none)
for p in <status pages>; do echo "$p items=$(grep -cE '^- \*\*20' $p) owed=$(grep -c 'Closing read owed' $p)"; done
```

A hit on a status page or in an evidence tier is fine; a hit in a design doc is a sentence to rewrite in the present tense with the evidence cited by record. An `items` count above `owed` is an item that landed and did not leave. Then re-read each modified doc as one narrative, resolve every moved basename and path, and grep live docs for each superseded term.

## The dotfiles repository — skip elsewhere

No mandatory onboarding set, so the root `CLAUDE.md` cost is reported apart from package-local and landing-page costs. The **protected set** — echoes a distillation keeps in meaning, not in narration: the red-line summaries in the root `CLAUDE.md` (details: `docs/stow-layout.md`, `docs/testing.md`); the cheat sheet in `tmux/.config/tmux/workflow.md`; the dated measurements in `docs/ghostty-fonts.md`, the Mac mini status snapshot and workaround probes; the suite commands in `docs/testing.md` and the exact commands in migration and recovery runbooks. Rot with a check rather than a restated rule: a suite is identified by its responsibility; a feature-disable gate is reflected in its workflow and design doc.

## The standards file itself

Rules accrete one incident at a time. A new rule enters as a line in the check block or a worked example first, and as prose only when neither can carry it; a rule that exists and was still broken gets a check, not a second statement. The file stays under ~10 KB. Review it, the doc skills and the tree's shape every few months or after a major model release: guardrails written for an older model become friction for a newer one, and removing stale guidance weighs the same as adding new.

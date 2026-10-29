---
name: distill-handoffs
description: Reconcile handoff briefs with what the repo has since done.
disable-model-invocation: true
argument-hint: [nothing on a feature branch → close out this branch; `folder` → the whole folder; a question, e.g. "can the cutover work move up?" → answer it]
---

# Sweep the brief folder

Handoff briefs live under `~/dev/.handoffs/<project>/`, one per next session,
each written by a session that saw only its own PR. What a brief asks for
usually survives; what it says about the world drifts. The sweep owns the
cross-brief view (a premise that shipped, a gate that discharged, two briefs
on one seam) and keeps the folder a task board: the notes (§ The folder note)
and the listing say what to do next, and finished work is gone.

**Defer to the project first.** If the repo ships its own sweep skill (look in
`.claude/skills/` for one that names this skill), run that. It carries what
this skill cannot know: where the project keeps status, how it reads
production, what a merged PR owes besides its brief. Its additions run after
step 1 of whichever pass fires, and its report section follows this one.

## Pick the pass

| the invocation carries | pass |
|---|---|
| a question | **question-led**: answer it, then make the folder agree |
| `folder`, or nothing on the default branch with no branch named | **reconcile**: the whole folder against the repo |
| a branch or slug, or nothing on a feature branch | **closeout**: that branch's briefs alone |

Closeout takes the branch that landed: the argument, else the one the user's
words name, else `git branch --show-current`. Name the pass first. Across all
passes:

- **Scope** is the briefs the pass names, plus every brief whose listing row
  reads `#N merged`: finished work is finished wherever it sits. Any other
  brief file stays unread and unedited, whatever drift the listing shows. The
  notes are always in scope.
- **State comes from the repo.** The listing joins PRs and branches through
  each brief's branch (the slug, or `<domain>/<slug>` in a domain corpus). It
  knows nothing of file sets or production, and a miss reads finished work as
  nothing. So read `git worktree list`, `gh pr list --state open` and
  `git diff --stat <default>...<branch>`; do not infer them.
- **Write in the same turn.** A verdict the repo already backs (a merged
  branch deletes, a discharged gate is noted, a retired name leaves the note)
  is applied when reached. Only § What waits goes to the human, and the report
  records what was written.
- **Work on a current copy, and publish what you wrote.** A folder that is a
  git clone is written from other machines and by teammates. Pull before the
  first read (`git -C <folder> pull --ff-only`, the command `brief`'s header
  prints); if the pull refuses, go on and say the copy may be behind. A pass
  that wrote ends on `brief sync`.
- **Brief prose follows the handoff skill:** `~/.claude/skills/handoff/SKILL.md`
  § 4, or the repo's own handoff skill. Read it when a verdict writes brief
  text.

## Closeout

A branch landed. Its brief is spent, and the briefs that named it may have
moved.

1. **Establish the branch and prove it landed.** Run `brief` first: every row
   reading `#N merged` is a second anchor. Then `brief closeout <branch>
   --json` returns the anchor (the brief named `<branch>` or `review-<branch>`,
   live or retired, or `null`), the landed state from gh, the files the
   branch changed, and every live brief that might belong, each with reasons:
   `relation` (a lineage field on either side names the other), `path` (its
   `paths:` overlap the changed files, listed in the file for step 2), `prose` (it names the anchor outside a
   lineage field), and, only beside one of those, `domain` and `run`. Read it
   through this digest:

   ```bash
   S=<your scratchpad directory>
   brief closeout <branch> --json > "$S/closeout.json"
   jq -c '{anchor: .anchor.slug, merged: .landed.merged, pr: .landed.pr.number, files: .changed.files, complete: .changed.complete}' "$S/closeout.json"
   jq -r '.candidates[] | [.slug, ([.reasons[].kind]|unique|join("+")), ([.reasons[]|select(.kind=="relation")|.detail]|join("; "))] | @tsv' "$S/closeout.json"
   ```

   ```
   # the shape, not today's folder
   {"anchor":"feat/client-data-corpus-by-default","merged":true,"pr":5941,"files":26,"complete":true}
   feat/client-data-corpus-reuse-on-publish   domain+path+prose+relation+run   its rests-on: names the anchor (line 21)
   infra/loopy-master-disk-throughput         domain+path+relation             anchor's collides-with names it; its rests-on: names the anchor (line 27)
   fix/ux-cut-turn-honesty                    path
   ```

   `complete: false` means some changed files went unread; the file's `list`
   command prints them all. If gh reads the branch unmerged but the
   invocation says it landed, run the command once more, since a merge clicked
   seconds earlier reads open. Then do steps 2–4 on what it shows, hold the
   writes, and end the report with `/distill-handoffs <branch>` to run once
   the PR reads merged.
   Done when the landed state is read and the anchor is resolved or its
   absence explained.

2. **Judge the scope from the reasons, before opening any body.** `relation`
   admits. `path` admits when the overlap is the anchor's subject rather than
   plumbing both touch: read the overlapping files, not their count. `domain`
   and `run` never admit alone, since a shared folder or route names half a
   busy folder. Write the scope as a list, one reason per line.
   Done when every candidate carries admit or exclude with its reason.

3. **Read the anchor and each admitted brief whole, and `brief drift` the
   admitted ones.** Look for what this branch made moot (a premise it
   shipped, a gate it discharged, a collision it settled) as much as what it
   falsified.

4. **Verdicts** (§ Verdicts): the anchor deletes when its work landed and is
   rewritten when its premise died; each admitted brief gets a field to
   correct, a note, or nothing.

5. **Write** per § Verdicts, references before files, holding back only § What
   waits. Re-anchor every brief you edited and `brief check <slug>` each. A
   `brief check` warning on a brief you did not touch goes in the report.
   Then `brief sync`.
   Done when `brief check <slug>` is clean on every brief you touched and
   `brief sync` has printed its outcome.

6. **Remove the checkout.** Step 5 changed the order the file recorded, so
   write it again and read the cleanup and the order from it:

   ```bash
   brief closeout <branch> --json > "$S/closeout.json"
   jq -r '.cleanup[]? | (.command // ("hold: " + .hold)) + (if .note then "   # " + .note else "" end)' "$S/closeout.json"
   jq -r '.next[] | .command + (if .gated then "  (gated)" else "" end)' "$S/closeout.json"   # next first
   ```

   A `gwt remove` line is a verdict the repo backs, so run it without asking.
   Make it the pass's last tool call, because it can delete the session's
   working directory, and run it from the checkout its note names
   (`cd <path> && gwt remove …`). gwt refuses a dirty, untracked or locked
   checkout, and one whose tip moved since closeout (`--expect-head`). What
   it refuses, any `hold`, and any line step 5 did not apply stay for the
   user.
   Done when the `gwt remove` JSON is read, or the cleanup has no such line.

7. **Report**, in short prose: what landed, in a line; the anchor's verdict
   and what was written; per admitted brief, what moved and the edit made;
   the note changes and the `brief sync` outcome; how many briefs were out of
   scope and unread. Under their own heading, the items that wait, each with
   the one word that releases it, or a line saying nothing waits. End on what
   the user would otherwise ask: what gwt removed or why it refused, the
   cleanup left to them, then the `next` commands.

## Reconcile

The periodic pass over everything, every few days or after a busy week. Most
briefs come out untouched. A folder of one or two briefs has no cross-brief
view: run steps 1 and 3, and report the verdicts alone.

1. **State.** `brief` and `brief --json` join every brief against the repo
   and decorate each gate with its PR's state. Add the reads the join is too
   shallow for (the state rule above). The listing ends on what the folder
   owes: a retired or unknown slug a note names, a live brief nobody placed
   in the order, a domain folder with no README. Those are the worklist.
   Done when every branch or PR the folder implies has a state you read.

2. **Read** it yourself, since a delegated summary drops the file and path
   sets collisions are found by: every brief's head, and the whole of every
   brief whose state moved (merged, PR opened, gate discharged, non-zero
   drift).

3. **Reconcile**, one verdict per brief:
   - a merged branch is finished work: delete it (§ Retirement);
   - a legacy `.md.done` without a `kept:` stamp: judge it once under §
     Retirement, delete or stamp;
   - each `blocked-by` was true the day it was written, and gates discharge
     quietly: verify each against the repo;
   - a domain whose last brief left loses its paragraph, and an emptied domain
     folder its README;
   - `brief drift <slug>` on every non-zero drift, read for the instructions
     it makes moot as much as the claims it falsifies;
   - step 1's `--stat` file sets against each brief's paths, since a branch
     grows into a collision with no brief changing.
   Done when every brief carries a verdict.

4. **Write** per § Verdicts, holding back only § What waits, then `brief
   sync`. Done when every touched brief has a fresh anchor, `brief check` is
   clean and `brief sync` has printed its outcome.

5. **Report.** The deliverable is a refresher for someone who wrote these
   briefs and no longer remembers them: what each domain is about; per brief,
   its goal in a sentence, its state, and **rewrote**, **noted**, **deleted**
   or **left**; the collisions and the order they imply. Under their own
   heading, the verdicts that wait, each with the one word that releases it.

## Question-led

"Can the cutover work move up?" is a judgment about the work; the folder
edits follow from it. The user has usually warmed the context before asking,
so spend that reading rather than repeating it.

- Read every brief whole. A partial read gives a confident map of the wrong
  shape, and the map is what the question asks for.
- Verify what the answer turns on (a gate called discharged, a status line, a
  quoted number) against the repo, and running behavior against production.
  The briefs are the documents the user is asking you to doubt.
- Derive only the cross-brief view the question needs: domains, collisions
  from the diffs rather than the declared fields, the gates, and the order
  they imply. Weigh the note's ordering properties rather than re-ranking from
  scratch, and treat any state it asserts as a claim to measure.
- Answer plainly, "no" included, naming what would change the answer and what
  you could not verify.

Then run Reconcile steps 3–5, which the answer usually moves. The report leads
with the answer and carries the verdicts under it.

## What waits

Four verdicts spend a judgment the repo cannot back. Only these wait for the
human; do everything else first and list these under their own heading, each
with the one word that releases it:

- **rewrite**: a successor brief is a new goal, and a goal is a design;
- **keep** over delete: a `kept:` retirement;
- **delete** of a brief whose branch does not read merged. Its release also
  deletes the branch on origin when `brief start` published one (`git push
  origin --delete <branch>`, the slug or `<domain>/<slug>`), since a branch
  there reads `started` on every machine;
- a change to the **order** beyond slotting an unplaced brief or dropping a
  retired name, and a domain coined or removed.

## Verdicts

Each verdict is a fact the sweep found, not a design it chose; the receiving
session keeps the design. A fix shape written into a brief turns it into a
work order. Where a shape must be recorded, record its provenance beside it:
proposed by whom, costed or not, what it has yet to answer.

- **Delete**: the work landed. § Retirement.
- **Rewrite**: the premise died. `brief new <forward-slug>` scaffolds the
  successor, every lesson and dead end that still holds moves into it, and the
  superseded brief is deleted. Two briefs for one goal is the rot this skill
  clears.
- **Note**: the edges drifted (a discharged gate, a new collision, a
  measurement already paid for). Fold it into the section it bears on, as the
  case rather than the verdict. A gate on a production read is discharged
  only by a read you ran with the project's own production-reading skills;
  otherwise note the merge and leave the gate, since "deployed" in the
  invocation is the release, not the read. A boundary move is written into
  both briefs, so neither session learns of it from the other's absence.
- **Leave**: nothing moved.

Write references first (the notes, the sibling head fields the CLI lists),
then the file, then `brief anchor <slug> --by sweep` on every brief edited.
An edited brief on its old anchor sends the next session to re-run drift you
already resolved. `brief set <slug> <key> <value>` rewrites `pickup` or `run`,
and `brief mv <slug> --domain <folder>` moves a brief to another domain. Edit
a lineage list (`rests-on`, `blocked-by`, `collides-with`) in the file, one
`  - ` item at a time, and run `brief check <slug>` to prove the head still
parses before touching anything else.

## Retirement

A brief is a view onto durable artifacts: the PR, the docs the sync updated,
the issue or spec record. Once the work lands the view shows nothing more.

- **Delete** with `brief delete <slug>` (exact slug, live or retired) once you
  can name the durable home the report will cite. It refuses while a head
  field or a note still names the slug: amend the note, drop the sibling
  items (a `supersedes:` naming a deleted brief points at nothing), fold any
  lesson a successor still needs into its body, then delete. Read a live
  successor's lineage before deleting what it names, since the reference
  report goes silent once a referrer is gone. An `.evidence/` dir stays on
  purpose, because the repo's docs cite these by path; grep `docs/` for
  `.evidence` before removing one by hand.
- **Keep** is the one exception: a named live successor depends on a passage
  unique to this brief, and no durable owner can take it without loss. Fold
  when you can. Otherwise `brief retire <slug> --reason "kept:
  <successor-slug> needs § <section>"`. The next reconcile reads the `kept:`
  prefix to know the judgment was made, and re-judges the file when the
  successor lands.

## The folder note

The notes hold what the listing cannot derive: what each group of briefs
means, and the order to work the live briefs in, with the properties that
order rests on. They exist only in a folder with a root `README.md`, which
keeps its briefs in domain folders. The root README carries the order and
what crosses domains; each domain folder's `README.md` says what its briefs
are about and why each sits where it does. Membership, goals and state live
in the listing; a copy in a note is stale by the next merge.

- Notes name live briefs only. A retirement removes the slug in the same
  write, and `brief check` flags a retired or unknown name and a domain
  folder with no README.
- A live brief `brief check` reports unplaced, in scope or not, is slotted
  from its listing row where the order's stated properties put it, in the
  same pass, and the report says where and why. A rank the user wants
  elsewhere is one word back; a deferred slot is the same warning on every
  pass.
- A note says nothing about which briefs are in flight or landed; delete such
  a line at the next amend. What a landed branch settled, deployed or
  measured lives in the docs and PRs.
- A date or identifier appears only as an unresolved constraint on a live
  brief ("run `<slug>` before the vendor cutoff on 2026-09-01"). A watch that
  needs action gets a brief; one that needs none lives in its issue or
  runbook.

Amend a note when a group's meaning shifts, a name is coined or retired, or an
ordering property proves wrong. A flat folder has no notes: the listing is its
whole view. A folder that has grown groups worth naming moves into domain
folders under a root `README.md` (`brief mv <slug> --domain <folder>`). A
wave list with dates is the listing's job, and goes stale in days.

## Escalation: session history

When a brief's provenance is unclear (what it was written from, or work the
user recalls that no PR or doc records), the transcripts hold it: use the
`obelisk` skill with the question named first. A dig costs minutes and a
large budget, so spend it on one specific unknown, not on a brief that reads
thin.

---
name: handoff
description: Wrap up the session into a brief for the next.
disable-model-invocation: true
argument-hint: "optional: the next session's goal, e.g. 'next: wire the retry path', 'review posture: not merging yet' — or 'nothing queued'"
---

# Hand off the session

The session is ending. The docs keep the project's durable model, but where
the work stopped, the dead ends and the next move live only in this session.
Write them into a brief under `~/dev/.handoffs/`, filed by project and named
for where the work goes next.

The brief is a prompt, not a report. The next session reads it whole as its
first input, in a fresh worktree or, in review posture, in this one. Every
line is an instruction to that agent.

**Defer to the project first.** If the repo ships its own handoff skill for
this work (look in `.claude/skills/`), run it. Add only what it lacks: if it
shows a kickstart without saving one, write that kickstart into a brief here
too.

## 1 — Gate: does this session earn a brief?

A brief nobody planned sends the next session down a road nobody chose. The
invocation's arguments may already name the next goal, which settles this
gate. Otherwise classify the ending:

- **Thread continues:** the work is unfinished, or a next milestone is known.
  Run steps 2–5.
- **Stopped mid-task:** context or time ran out before the work landed. The
  brief is the most valuable thing you can leave. Run steps 3–5 now and make
  the doc pass one of the brief's first moves.
- **Done but not trusted:** the work is complete, but the user has said it
  does not merge yet, usually because edge cases kept surfacing after earlier
  "done" claims. Run steps 2–5 in review posture (step 4).
- **Work landed, nothing queued:** an isolated fix or feature, done and
  verified. Ask one question: *anything queued for the next session, or doc
  pass only?* If nothing is queued, run step 2 and step 3's Neighbours, then
  print `/distill-handoffs` for the user. Its closeout deletes the brief that
  spawned this branch once the work has a durable home. Only the user can run
  it, and this skill sees one brief, not the folder.

Review posture starts only on the user's verdict, in the arguments or in the
session, never on your own read of the work. A clean ending with a natural
next goal gets a forward brief with no question. When the ending looks like
*done but not trusted* (a large or bumpy branch, bugs found after green
claims) but nobody said so, ask once: *merging this and moving on, or holding
it for a review session?*

## 2 — Doc pass

The docs are the durable memory; the brief only bridges sessions. If the
branch changed anything doc-worthy, run the project's update-docs skill or
its `documentation-standards.md`, else the global `/update-docs`. Skip it
when a doc pass already ran this session or the diff is implementation-level.

The doc pass needs only the diff, but the brief needs this session's memory.
When the window is already deep, write the brief first and make "run the doc
pass" its first move, so the pass runs in a fresh window.

Done when the docs are updated or the skip is named ("deferred to the next
session", "implementation-level").

## 3 — Harvest what only this session knows

The diff shows what changed. Collect what it cannot show.

**Lessons**, the conclusions the next session should inherit:

- Decisions made, and the alternatives they beat.
- Dead ends, and why they failed. A fresh session tries these first unless
  told.
- Invariants the work established that the next change must not break.
- Verification state: what was tested, and what was only written.

**Friction**, mined now because the wrap-up glosses it: fixes that took
several attempts, code reread before it could be trusted, assumptions that
broke, too many cases held in mind at once. Call each point **essential**
(the problem is that hard) or **accidental** (the design made it hard).
Essential friction joins the lessons. For accidental friction, name the
struggle and the reshape that would have removed it. You built what you are
judging, so hand over the case, not the verdict.

**Neighbours**, the live briefs this session moved without writing them. A
lesson, a measurement or a change can falsify a sibling's premise, discharge
its gate, or collide with a path it plans to touch. Find them in the domain
folder's `README.md` and in `brief related --paths <the paths this branch
changed>`. Write the case into each moved brief as the sweep's **Note** would
(`~/.claude/skills/distill-handoffs/SKILL.md` § Verdicts): the fact and its
evidence, with what has landed kept apart from what is still on this branch.
Then run `brief anchor <slug> --by sweep` and `brief check <slug>` on each.
Deleting, rewriting or reordering a sibling stays the sweep's, after the
merge. Neighbours runs whether or not this session writes its own brief.

Done when each lesson says why you believe it and how sure you are, each
friction point carries its call, and each moved neighbour carries the case. A
session that taught nothing and fought nothing gets a brief of state and next
move only.

## 4 — Write the brief

```sh
brief new <slug> --pickup build|design [--domain <folder>]
```

It prints the scaffolded file, with `anchored:` and `base:` stamped from the
repo. Leave those two alone and fill the rest. Use `--domain` when the
handoff folder keeps domain folders (it has a root `README.md`); `brief new`
lists them when the flag is missing.

**`--pickup` sets the next session's first turn**, and `brief start` refuses
a brief without it. Choose `build` only when something outside this session
reviewed the approach: a spec the user approved, a consult record, a PR to
continue. Otherwise choose `design`. The gates are
[`pickup/build.md`](pickup/build.md) and [`pickup/design.md`](pickup/design.md):
the receiving session's first turn re-grounds the user, checks the premises
and names the next move, usually a consult, before any edit. Read the gate
you chose before writing `## At pickup`, since that section is its input.

**`<slug>` is the branch the next session will work on**, not this one. It
names the file, the branch and the worktree at once, qualified by its folder
in a domain corpus (`ux/cut-turn-honesty.md` is branch `ux/cut-turn-honesty`).
Read [`SLUG-NAMING.md`](SLUG-NAMING.md) before choosing: the name must pass
its cold-read test. A same-named file is an earlier brief for the same goal,
so overwrite it with `--force`. Two live briefs colliding means one slug is
too vague; sharpen it.

**The head.** Each rule below is the residue of a real failure.

- `goal:` is the next session's goal in a phrase, with its two or three
  strands. Every folder listing shows it before anyone opens the file, so
  write it for that cold reader.
- `run:` is the project's onboarding skill and its short route. Omit it where
  the project has none; the goal then opens the session.
- `paths:` lists the repo-relative paths the brief's claims live in, as
  narrow as the work. `brief drift` and `brief related` read them, so a whole
  app directory returns every PR the repo merged.
- `rests-on:` names the PRs, branches or changes the brief assumes, each with
  its state at writing.
- `blocked-by:` holds world-state gates the next reader can verify ("a prod
  deploy carrying #5181"), one per item. **`none` stands alone.** A real gate
  once hid for weeks in "none — but #5181 must be deployed"; anything beyond
  a bare `none` is a gate and gets its own `- ` item. The scaffold writes
  `none` here and in `collides-with:`; it is a claim that you looked, and
  `brief check` cannot tell it from one nobody checked.
- `collides-with:` names sibling briefs as `<slug> · <why>`. A collision
  with no slug, such as a path or a person's strand, is prose.
- Values are plain prose. Indent a continuation two spaces, grow a list with
  `  - ` items, and quote nothing.

**The body.**

- **First moves** opens with `brief drift`, then says what to weigh in its
  output: each `rests-on` entry's consequence, and which instructions the
  drift would make moot. Then name the two to four reads the task hinges on,
  one line of why each, and the project skills the work runs through. Stop
  there: the first-turn contract lives in the gate, and a second copy in the
  body is the one a reader skips.
- **`## At pickup` is always the last section.** It carries one to three
  load-bearing claims, the ones a receiving session would take on faith and
  be wrong about. Run each check before writing its line and record what it
  returned; a claim wrong at writing is otherwise found at pickup, after the
  reader rebuilt the instrument. A check you cannot run is written
  `unverified — <what would settle it>`. An instruction whose target may ship
  while the brief waits is a claim too: say what is absent, with its check.
  A stable one-line command rides inline; a bespoke query goes in
  `<slug>.evidence/` and the line cites it.

  <example>
  - `runProvider` records the engine that served a run and `requestedRunProvider` the one intended · check: `packages/db-schema/prisma/schema/loopy.prisma`, the two column comments · observed at 1b55b6d260: both comments present, served vs intended · falsified by: a row with `runProvider = 'local-master'` whose events carry Inngest step ids
  - Five file-referenced chart runs have served on flipped workspaces · check: the `text_delta {op:'reset', reason:'file-reference'}` rows by workspace · unverified — the prod endpoint was not held this session; a count of five settles it · falsified by: fewer than five after a week of serving
  </example>

  Cite each claim's files by repo path or symbol, so drift can attribute a
  PR to it. Cite a member beside its declaring file (`src/store.ts`
  `lookupKey`, not `Store.lookupKey`): a dotted name matches only the call
  sites and docs that spell it that way, never the declaration.
- A design brief's **Proposed approach** gives the gate its target: the bet,
  its evidence, and the observation that would change the choice. For a fix,
  open it with the claimed cause: what was observed, then the chain inferred
  from it. Fill its other slots too (optimizes for, accepts, weakest
  support, direction-changing evidence): `brief check` passes a brief whose
  approach and claims still read TODO. Leave the direction of attack to the
  receiving session.
- **Visible product forks** name each fork with its options and your
  recommendation; the scaffold's `- none` is again a claim that you looked.
- The goal and the invocation live in the head only. A copy in the body
  gives the next session two versions to disagree.
- Every path is repo-relative, since the next session works in another
  worktree. Cite specs, PRs and issues by path or URL.
- Call it "this brief", never a file: the text outlives its filename.

Point rather than pre-chew. Carry the goal, the constraints and the evidence
this session paid for, and leave the shape of the fix to the session that
will own it. A sketched fix is marked as a sketch, with what it has not
answered: written as a requirement, it spends the next session's judgment
before it starts, and the least-able session writes it most confidently.
Cite what an artifact already holds (the docs just updated, specs, issues,
commits) instead of restating it. Redact secrets: keys, tokens, and log lines
carrying them. Keep the body before `## At pickup` near 150 lines.

**Review posture** hands the branch to its reviewer, not its continuer. Same
rules, four differences:

- The slug is `review-<this-branch>`, the whole branch name with its domain
  (`review-ux/cut-turn-honesty`). The body opens by pinning the next session
  to this same branch and worktree, since the branch merges only after the
  review passes. Worktree-local artifacts (gitignored scripts, scratch
  harnesses) are citable.
- A posture block opens the body. It names why trust broke (the edge cases
  and bugs the user found after earlier "done" claims) and sets the stance:
  every conclusion, this brief's included, is a claim to re-verify, and the
  accreted fixes are read as hiding more seams.
- "Where things stand" carries the review surface: each mechanism or
  workaround the branch accreted, one line each, mechanism → home file.
  Suite numbers come with "re-run before trusting".
- `pickup:` is `build`; the posture block, not the gate, sets the adversarial
  stance. Unless the arguments set an agenda, `goal:` carries the standing
  one: does the accretion compose or hide seams, what to extract and where,
  why the suite stayed green over the escaped cases, and what harness would
  catch that class. First moves offers the user `/review` as a cold read
  beside the session's own.

Done when the brief passes the cold-pickup test: every pointer resolves from
inside the receiving worktree, nothing depends on this session, and the
filename names where the next session goes. Then:

```sh
brief check <slug>    # clean is the bar
brief                 # your row beside its siblings
brief sync            # publish, when the folder is shared
```

Read your row in the listing. It shows what the file only claims: the goal,
gates and collisions as a cold reader meets them. A folder that is a git
clone reaches other machines and teammates only once `brief sync` prints
`published`.

## 5 — Close

Show the user, together, the path step 4 wrote, a two-line summary of what
the brief carries, and the pickup command:

```sh
brief start <slug>
```

It places the worktree (or re-enters this one in review posture) and hands
the session its opening pointer. Handed off means one command starts the next
session.

## Continuation mode — the brief between two sessions on one branch

With `continuation` in the invocation's arguments, write the brief a fresh
session opens to continue the same work on the same branch, typically after a
spec is settled and its writer is replaced by an implementer. Against the full
mode:

- The branch exists and the next session works on it, so choose no slug and
  name no worktree.
- Write to the path the caller names, not `~/dev/.handoffs/`.
- Run no `brief` command and name no pickup gate: the next session opens on
  the prompt its caller composes, which carries this brief whole.
- Defer the doc pass to whatever syncs the docs after the review.
- The head keeps only `goal`, `paths`, `rests-on`, `blocked-by` and
  `collides-with`.

The harvest (step 3), the four body sections (Where things stand; Lessons,
dead-ends, and friction; First moves; At pickup), point rather than pre-chew,
repo-relative paths and the length budget all stay. Done when the file reads
cold as the first thing a session with none of this context opens.

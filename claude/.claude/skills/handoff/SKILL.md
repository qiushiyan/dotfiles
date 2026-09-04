---
name: handoff
description: Wrap up a session into a brief for the next one — an optional doc pass, the session's harvest (lessons and friction), and a handoff file named for the next session's branch, ready to pick up with one command — or re-entered in review posture when the branch isn't ready to merge.
disable-model-invocation: true
argument-hint: "optional: the next session's goal, e.g. 'next: wire the retry path', 'review posture: not merging yet' — or 'nothing queued'"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git worktree list:*), Bash(brief:*), Read, Write, Edit, Glob, Grep, Agent
---

# Hand off the session

You're ending a working session. The docs keep the project's durable mental model, but what only this session holds — where the work stopped, the dead-ends, the next move — evaporates when it closes. This skill writes that brief: a handoff file under `~/dev/.handoffs/`, filed by project and named for where the work is going next.

**The file is a prompt, not a report.** The next session starts in a *fresh worktree* — or, in review posture, right back in this one — and this file is the first thing it reads whole: every line you write is an instruction addressed to the agent receiving it.

**Defer to the project first.** If the repo ships its own handoff skill scoped to this work (check `.claude/skills/`), its process is authoritative — run it, and add only what it lacks: if it presents a kickstart without persisting it, write that kickstart into the `~/dev/.handoffs/` brief too.

## 1 — Gate: does this session earn a brief?

A manufactured handoff sends the next session down a road nobody planned. `$ARGUMENTS` may already name the next goal — that answers this gate. Otherwise classify the ending:

- **Thread continues** — work unfinished, or a known next milestone → full handoff: steps 2–5.
- **Stopped mid-task** — context or time ran out before the work landed → the brief is the most valuable thing you can leave. Run steps 3–5 now and fold the doc pass into the brief's first moves.
- **Done but not trusted** — the work is "complete" but the user's verdict is that it doesn't merge yet — edge cases kept surfacing after earlier "done" claims — and the next session re-reviews this branch's work before any merge → full handoff: steps 2–5 in **review posture** (step 4 defines it).
- **Work landed, nothing queued** — an isolated fix or feature, done and verified → ask the user one question: *anything queued for the next session, or doc pass only?* If nothing's queued, run step 2 alone and close by printing `/distill-handoffs` for the user: its closeout pass deletes the brief that spawned this branch (`<branch>` or `review-<branch>`) once the work has a durable home and settles the briefs that named it, within this branch's domain only. Only the user can invoke it, and this skill writes one brief without seeing the folder around it.

Review posture is entered on the user's verdict — `$ARGUMENTS` or the session saying the branch isn't ready — never on your own read of the work. A clean ending with a natural next goal is a forward handoff: write it, no question. When the ending shows the *done but not trusted* signature but the verdict was never spoken — a large or bumpy branch, bugs found after green claims, no merge decision stated — settle the gate with one question: *merging this and moving on, or holding it for a review session?*

## 2 — Doc pass

The docs are the durable memory; the brief only bridges sessions. If the branch changed anything doc-worthy, run the project's own update-docs skill or `documentation-standards.md` (the global `/update-docs` standards when the project has neither). Skip when a doc pass already ran this session, or the diff is implementation-level.

**Timing rule:** the doc pass needs only the diff; the brief needs this session's memory. When the window is already deep — you'd hesitate to re-read the overlapping docs end-to-end — write the brief first and make "run the doc pass" its opening move, so it executes in a fresh window.

Done when docs are updated, or the skip is named ("deferred to next session" / "implementation-level").

## 3 — Harvest what only this session knows

The diff shows what changed. The harvest collects what it can't show, in two halves — what the session learned, and what it fought.

**Lessons** — conclusions the next session should inherit:

- Decisions made and the alternatives they beat.
- Dead-ends — approaches tried and abandoned, and why. A fresh session re-attempts these first unless told.
- Invariants the work established that the next change must not break.
- Verification state — what was tested, what was merely written.

**Friction** — where the work actually hurt, mined now because the wrap-up is what glosses it: fixes that took several attempts, code re-read repeatedly before it could be trusted, wrong turns, assumptions that broke, places too many cases had to be held in mind at once. Make one call per point: **essential** — the problem is genuinely that hard — or **accidental** — the current design manufactured the struggle. Essential friction joins the lessons ("harder than it looks, and why"). Accidental friction is a design signal: name the concrete struggle and the reshape that would have dissolved it. You built what you're now judging, so hand the next session the case, not the verdict.

Done when every kept lesson carries why you believe it and how sure you are, and every friction point carries its essential-or-accidental call — a session that taught nothing and fought nothing gets a brief of state + next move and nothing else; the honesty floor cuts both ways.

## 4 — Write the brief

```sh
brief new <slug> --pickup build|design [--cluster <workstream>]
```

prints the file it scaffolded, folder created, with `anchored:` and `base:` already stamped from the repo — leave those two alone and fill the rest.

**`--pickup` names how the next session's first turn runs**, and `brief start` refuses to launch a brief without it. `build` only when the approach is already reviewed — a spec the user approved, a consult record, a PR to continue; otherwise `design`. The gate each value fires is [`pickup/build.md`](pickup/build.md) / [`pickup/design.md`](pickup/design.md): the receiving session ends its first turn on that gate's contract — a re-grounding written for the user who has lost the thread, the premises checked, the next move named (usually a consult) — before any edit. Neither gate skips the consult; `build` only narrows what it asks. Read the gate you chose before writing `## At pickup`, since that section is its input.

**`<slug>` is the branch the next session will work on**, not the one this session worked on: one token for the file, the branch, and the worktree. Write it as you'd write the branch, because it is the branch. [`SLUG-NAMING.md`](SLUG-NAMING.md) carries the **cold-read test** it has to pass — a place and an outcome, in words the tree already uses; read it before you choose, and note that a project skill wrapping this one may bind it to that project's own vocabulary.

A same-named file is an earlier brief for this same goal — overwrite it (`--force`). Two *live* briefs colliding means one slug is too vague; sharpen it.

The head is typed fields between `---` fences; the body under them is yours:

```markdown
---
goal: <the next session's goal in a phrase, with its 2–3 strands. One
  logical line — indent continuations two spaces. Every folder listing
  shows this before anyone opens the file; write it for that cold reader>
run: /<onboarding-skill> <route>
anchored: <stamped — leave>
base: <stamped — leave>
cluster: <workstream>
pickup: build | design
paths:
  - <repo-relative path>
rests-on: <the PRs, branches or changes whose state this brief assumes,
  each with its state at writing>
blocked-by: none
collides-with: none
---

## Where things stand
## Lessons, dead-ends, and friction
## First moves
## At pickup
```

Head rules — each is the residue of a real failure:

- Values are plain prose: a continuation line is indented two spaces, a list grows `  - ` items, nothing is ever quoted.
- **`none` stands alone.** A real gate once hid for weeks inside "none — but #5181 must be deployed" and read as no-gate; anything beyond a bare `none` *is* a gate — give it its own `- ` item.
- `blocked-by:` carries **world-state gates** the next reader can verify — "a prod deploy carrying #5181", "green nightly at k=3" — one per item. Always answered: `none` is an assertion that you looked.
- `collides-with:` names **sibling briefs**, `<slug> · <why>`; a collision with no slug (a path predicate, a person's strand) is written as prose. `none` costs nothing and says you looked.
- `paths:` scopes the drift check the next session runs — list exactly the repo-relative paths this brief's claims live in.
- `run:` is the invocation the pickup fires: the project's onboarding skill plus its short route. Omit the field where the project has none — the goal then stands as the opening directive itself.
- `cluster:` joins the folder's workstreams; with no siblings it is load for nothing.
- `pickup:` is `build` or `design` — the test is above; the sweep may flip it when a design brief's approach settles.

Body rules:

- Open **First moves** with `brief drift`, then say — as prose only this session can write — what to weigh in what it reports: each `rests-on` entry's consequence, and which of this brief's instructions the drift would make moot. Then the 2–4 reads this task hinges on with one line of why each, and the project skills the work runs through — that is where First moves ends. The first-response contract has one home, the gate; a second copy in the body is the one a receiving session reads past.
- **`## At pickup` is the last section, always**, and carries only what this session uniquely knows, in the shape the gate consumes:

  ```markdown
  ## At pickup

  Load-bearing claims:
  - <claim> · check: <file, query, or record> · decisive result: <what would
    hold or falsify it>
  - <one to three total>

  Proposed approach:                                      <!-- design only -->
  - <what changes, where, and the bet it makes — for a fix, open with the
    claimed cause: what was observed, then the chain inferred from it>
  - optimizes for: <goal or constraint>
  - accepts: <known cost or capability given up>
  - weakest support or contrary evidence: <evidence, unresolved assumption,
    or none known>
  - direction-changing evidence: <observation that would change the choice>

  Visible product forks:
  - <fork> · <options known now; recommendation if one exists>
  - none
  ```

  The claims are the ones a receiving session would take on faith and be wrong; the approach block gives the design gate its target — the bet, its evidence, and the observation that would change the choice — and leaves the attack's direction to the receiving session, which reads every perspective fresh.
- **The goal and the invocation live in the head alone.** Open the body with the work — restating either would give the next session two copies to disagree.
- **Every path is repo-relative.** The next session lives in a different worktree; an absolute path into this one dangles. Cite files, specs, PRs and issues by repo-relative path or URL.
- **Refer to it as "this brief", never as a file** — the text outlives its filename.

Point rather than pre-chew — a brief that hands the next session answers instead of pointers robs it of the verification that would make them its own. The rule binds the *design* as well as the facts: carry the goal, the constraints, and the evidence this session paid for, and leave the shape of the fix to the session that will own it. Where you do sketch one, mark it as a sketch and say what it has not answered — an approach written in as a requirement spends the next session's judgement before it starts, and it is written most confidently by the session least able to test it. Reference rather than duplicate: anything already captured in an artifact — the docs the doc pass just updated, specs, issues, commits, diffs — is cited, never restated; the brief carries only what lives nowhere else. Redact secrets before writing — keys, tokens, pasted credentials or log lines carrying them — the next agent reads every line of this. Keep it under ~150 lines.

**Review posture** (the gate's *done but not trusted* ending) hands the branch to its reviewer, not its continuer. Same file, same rules, four deltas:

- The slug is `review-<this-branch>` — what's ahead is a verdict on this branch, not a new worktree, so the filename names the review instead of a destination. The opening of the body pins the next session to **this same branch in this same worktree** — the branch merges only after the review passes, so nothing new gets created. Worktree-local artifacts (gitignored scripts, scratch harnesses) are citable here: the next session can reach them.
- A posture block opens the body, naming why trust broke — the concrete edge cases and bugs the user found after earlier "done" claims — and setting the stance: the next session treats each conclusion, this brief's included, as a claim to re-verify, and reads the accreted fixes adversarially — assume they hide more seams.
- "Where things stand" carries the **review surface**: the mechanisms and workarounds this branch accreted, one line each, mechanism → home file — the shape to review, not re-derive. Verification state is claims, not facts: suite numbers come with "re-run before trusting".
- `pickup:` is `build` — the review's first turn verifies and restates before it judges; the posture block, not the gate, sets the adversarial stance.
- `goal:` names the review; unless `$ARGUMENTS` sets its own agenda, it carries the standing one — does the accretion compose or hide seams; what to extract and where the seams go; why the suite stayed green over the escaped edge cases, and the harness that would catch that class. First moves offers the user `/review` — a cold dispatched read to ride beside the session's own.

Done when the brief passes the cold-pickup test — every pointer resolves from inside the receiving worktree, nothing in it depends on this session or this file existing, and the filename names where the next session goes — and, mechanically:

```sh
brief check <slug>    # fix what it flags; clean is the bar
brief                 # your row beside its siblings
```

That second command is the half you cannot get by re-reading your own file: the listing renders what the file only claims — the goal as a cold reader meets it, the gates, the collisions — and the row either reads cold or it doesn't.

## 5 — Close

Show the user, together:

- the path step 4 wrote,
- a two-line summary of what the brief carries,
- and the pickup command:

  ```sh
  brief start <slug>
  ```

  It places the worktree (or, in review posture, re-enters the existing one) and hands the session its opening pointer — nothing to copy, nothing to remember.

Handed off means: one command, next session running.

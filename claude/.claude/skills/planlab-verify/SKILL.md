---
name: planlab-verify
description: (Planlab) Verify a branch by driving it where it runs. Use when a Planlab branch or fix needs proving beyond its tests.
---

# Verify a Planlab branch where it runs

You are proving that a branch does what it is for, by running it the way
the person or program that meets it does, and finding where it is fragile.
The prompt that sent you here may name what to verify; this skill says how
to choose it and where to run it. You are done when every behaviour the
branch exists to deliver has a verdict carrying the output that decides it,
the riskiest places beyond them are driven and reported apart, every claim
you could not drive says what would drive it, and everything you started is
torn down.

## What to prove

- **The target:** the behaviours the branch exists to deliver, each driven
  end to end through the entry point its user uses (a planner's message to
  Loopy, a page, the CLI, an API call, a host booting), with the changed
  behaviours meeting as they meet in use: a restart in the middle of a run,
  a second run on the same state, the page that renders the new field.
- **The risk:** beyond the target, where the change is fragile or would do
  the most damage if wrong: paths it shares with other features, a restart,
  deploy or migration in the middle of what it changes, the inputs each claim
  covers beyond the one that shows it working, the next consumer of what it
  produces. Choose by how likely each is to break and how much would break.

Read every line the runs print, not only the predicate you were checking. A
bare error, an instruction nobody can follow, or output naming something its
reader never receives is a finding, whatever the verdict.

When the branch's own tests already settle a claim (a pure function, a
refactor with parity tests, docs), say so and spend the drive elsewhere: a
drive costs about an hour and a half when it finds nothing.

## Where to run it

Map each claim to the rig that reaches it; one branch often needs several.
Each patterns file holds the commands that work today and what that rig
cannot tell you.

| The claim lives in | Rig | Patterns |
|---|---|---|
| One function, or Loopy's loop on inputs you give it | in process: a test, a Postgres test, `debug:run` | [lane](patterns/lane.md) § In process |
| Loopy turns, the pool, the app's routes and data | this worktree's lane | [lane](patterns/lane.md) |
| What a person sees and does in the app | a browser signed in to the lane | [browser](patterns/browser.md) |
| What a Linux host or tool does, Loopy's S3 staging, a service of its own | a container on this machine | [containers](patterns/containers.md) |
| AWS shape: EC2, systemd on a host, S3, IAM, a Lambda | the personal AWS account's kits | [aws](patterns/aws.md) |
| Production data, configuration or a deployed build | production, read-only, and your sandbox workspace | [production](patterns/production.md) |
| Loopy's prompts, tool text and skills | prompt checks, replays of real asks, blind judges | [model-facing](patterns/model-facing.md) |

Use the rigs that exist. When a claim needs one that does not, report what
would reach it: rig tooling is built as its own work. A throwaway driver
belongs in an untracked `application/scripts.local/` script or your
scratchpad.

A Loopy incident with a dossier from `pl-loopy-debug` is proved and closed
by `pl-loopy-verify`'s steps, which record the outcome the dossier needs.

## Keep it real

The code under test stays real: the module, the running app, the real
model when the story has one. When the claim is about specific data, that
data stays real too: the production row, the customer's file, the planner's
words. Name each fake you use and ask whether it could change the verdict;
where it could, make it real. Production runs the deployed build, not this
branch: to run the branch on a workspace's real data, read the data there,
which needs no permission, and load it onto the lane
([lane](patterns/lane.md) § Data in). A write in that workspace would test
only the deployed build, so it belongs to a check after the deploy.

A fix is red on a baseline (the build before it) and green here, and a
committed test or case that fails without the fix keeps it green; for a
Loopy fix, `pl-loopy-verify` § The artifact says which rung holds it. For a
new capability the baseline's red proves nothing, so run the existing flows
on both instead, which should agree. A claim about timing or concurrency gets
repeated runs; say how many.

## Writes, spend, and other sessions

- **Deployed workspaces,** by `CLAUDE.local.md`: your sandbox
  `planlab-dev-qiushi` freely, listed in the report; any other (a demo, an
  internal or lab workspace) on the owner's word.
- **AWS:** the personal account only. Launch the smallest shape the claim
  needs, tag it with the branch, and tear it down before you report. An
  expired sign-in stops you: signing in is the owner's.
- **Other sessions:** several run on this machine at once. A lane is yours
  alone; a container, a port, a bucket and a browser session are not, so
  name each after the branch, and list the sandbox threads you created by
  id.
- **Traffic:** nobody else sends to your lane, your sandbox or a lab
  workspace. An experiment names before it starts what sends its traffic,
  and how it makes sure a run is in progress when the event it tests
  happens.

## Report

Open with one line: behaviours verified of how many, the rigs used, claims
not driven, writes outside the lane, and whether everything is torn down.
Then the target: each behaviour, VERIFIED or NOT VERIFIED, the rig and the
build it ran on (the commit; a lane's result block names it), and the output
that decides it, quoted so a reader who never saw
the run reaches the same verdict. VERIFIED covers only what was driven. The
risk front follows apart, each probe with what it showed. Then what was not
driven, each with what would drive it: a rig that does not exist yet, or a
check owed after the deploy and when it can run. Then what waits for the
owner's word, such as a write you asked for. Last, what you wrote outside
your lane, what guards each red you fixed, and what you tore down.

Fix what you can within the branch, drive each red again once it is fixed,
and leave the decision to the owner where the fix would change the design.

# Driving iTELL sessions

An iTELL batch takes `learlab/itell` sessions from onboarding through a
merged PR that staging serves; the production deploy stays the user's. This
file holds what is iTELL's own. The stages and snippet keys are in
`~/dotfiles/docs/session-pipeline.md`, the rest of the drive in SKILL.md, and
a batch whose designs are unsettled stops at the design checkpoint as
[`PLANLAB.md`](PLANLAB.md) § The design checkpoint describes.

## Opening a session

Open sessions in the platform, not the repository root: the platform's
`CLAUDE.md`, its skills (`onboarding`, `verify`) and the hook that lints each
edit load only from `apps/platform`, so a session opened at the root runs
without them.

```bash
drive open T1 --dir ~/dev/itell/apps/platform --file /tmp/t1-start.md   # "… in a worktree of your own"
drive open T2 --dir ~/dev/itell/apps/platform '/bug-report-triage <reportId>'
```

A learner's bug report enters at `/bug-report-triage`; a fix it recommends
goes on with `/onboarding <its diagnosis>`. A change that also lands in the
CMS works in an `itell-cms` worktree of its own beside the platform's
(`apps/platform/docs/agents/cross-repo-cms.md`).

## Verification is a file you check

Stage 5 is `itell-review-verify`: the session drives its change in a
verification lane, its own world on the running platform, and ends its
report with the `verify:` line `pnpm verify verdict` printed — the branch's
claim, every scenario it ran at its head taken together, e.g.
`verify: 2 scenarios at 94a17a8219 — target 3 verified; risk 5 verified — passed`.
That line is the claim and the verdicts the evidence. Check them yourself;
it is a read, like `claude-steps show`:

```bash
cd <worktree>/apps/platform && pnpm --silent verify verdict --json   # works after the lane is down
git -C <worktree> rev-parse HEAD
```

The stage is done when the report's `passed` is true, its `branch` is the
session's and its `head` is the worktree's HEAD. `passed` means every run in
it is certified (it ran the committed code and every story proved something
either way), no story failed, and some target story was verified. A lane
belongs to the checkout a command runs in, so a report naming the main
checkout verified `main`, not the branch. Send the stage back with what is
missing:

- no runs, or `fronts.target.verified` 0: nothing drove what the change is
  for;
- a run not certified: its `problems` say why, most often "commit, then
  rerun", or a story that errored or asserted nothing;
- a failed story: a finding the session fixes. One it reports instead as
  out of the change's reach is a decision for the user, and holds the merge.

A blocked story is not a pass; one blocked on what lanes cannot supply
(scoring outside the seed's pages, Stripe) goes to the report as a limit.

## Lanes are shared machine state

- The machine runs at most four lanes, beside PlanLab's stack on the same
  Postgres. A start on a full machine waits up to 20 minutes for room, so
  sessions verifying together queue on their own; one whose `up` gave up
  ("stayed full") gets its step again once others are through.
- A lane is its session's: no session stops another's, and neither do you.
  Send the owning session `pnpm verify down` instead, as you would for a
  session you park overnight with its lane up.
- A session's stage 5 ends with its lane down. Before you close a session,
  check in its worktree: `pnpm verify status` answering "this worktree has
  no lane" (exit 2, its suggestion to `up` aside) is the state you want;
  a lane it still reports, the session brings down.

## Who can be hurt decides what you ask

The pipeline doc's § Who decides draws the lines; these are iTELL's spaces.

Do these, or let the session do them, and report them:

- anything inside a lane: its databases, servers and CMS are the session's;
- staging, a copy of iTELL that emails only the team: reads, and writes
  through the app;
- reads of production through the read-only role
  (`ITELL_PROD_READONLY_DATABASE_URL`).

Ask, holding only the work that depends on it:

- a write to a production database, including the CMS's content;
- the production deploy (below);
- a reply to a learner's bug report: draft it for the user to send.

## After the PR: merge, staging, production

iTELL PRs carry no review bots, so stage 8 has nothing to loop over; a
person's review comments are a fix step like any other. A complicated or
critical change gets a strategic review in a fresh session, as `PLANLAB.md`
§ After the PR describes; that session verifies in a lane of its own.

Merging is yours once the stages have run with a passed verdict at the PR
head. `merge-when-ready` has the session merge, follow the staging deploy
and check what staging shows a visitor. A change in both repositories
merges the side that answers first (`STAGING.md`). One session merges at a
time:

```bash
drive send T1@… --snippet merge-when-ready --hold itell-main
```

The production deploy follows a signed-in check on staging, and signing in
there needs an `@itell.ai` inbox, which only the user has: list it under
**Needs you** with the merge, what the session checked on staging, and the
deploy commands its report names. Then send the session `recap`, and its
`closeout` (the handoff distill), one session at a time.

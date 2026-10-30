# Driving iTELL sessions

An iTELL batch takes `learlab/itell` sessions from onboarding through a
merged PR that staging serves; the production deploy stays the user's. This
file holds what is iTELL's own. The stages and snippet keys are in
`~/dotfiles/docs/session-pipeline.md` and the rest of the drive in SKILL.md.
Two sections of [`PLANLAB.md`](PLANLAB.md) hold here too: § The design
checkpoint, for a batch whose designs are unsettled, and the strategic
review in § After the PR.

## Opening a session

Open sessions in the platform, not the repository root: the platform's
`CLAUDE.md`, its skills (`onboarding`, `verify`) and the hook that lints each
edit load only from `apps/platform`, so a session opened at the root runs
without them.

Sessions leave the untracked `apps/platform/supabase/` folder in the main
checkout alone: it links to production and is never committed.

```bash
drive open T1 --dir ~/dev/itell/apps/platform --goal '…' --file /tmp/t1-start.md   # "… in a worktree of your own"
drive open T2 --dir ~/dev/itell/apps/platform --goal 'Find what causes <the reported bug>, and whether it needs a fix.' '/bug-report-triage <reportId>'
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
session's and its `head` is the worktree's HEAD. What `passed` requires is
`apps/platform/docs/verification.md` § Scenarios and verdicts. A lane
belongs to the checkout a command runs in, so a report naming the main
checkout verified `main`, not the branch. Send the stage back with what is
missing:

- no runs, or `fronts.target.verified` 0: nothing drove what the change is
  for;
- a run not certified: its `problems` say why, most often "commit, then
  rerun", a story that errored or asserted nothing, or a `--keep-world` run;
- a failed story: a finding the session fixes. One it reports instead as
  out of the change's reach is a decision for the user, and holds the merge;
- a blocked target story: what the change is for went undriven. One
  blocked on what lanes cannot supply (scoring outside the seed's pages,
  Stripe) is a decision for the user, and holds the merge;
- a `leftOut` scenario with a failed story: the session ran it on the
  branch and it is not in the claim. Ask why before you accept the stage.

A blocked risk story is a limit for the report.

## Lanes are shared machine state

- The machine runs at most four lanes, beside PlanLab's stack on the same
  Postgres. A start on a full machine waits up to 20 minutes for room, so
  sessions verifying together queue on their own; one whose `up` gave up
  ("stayed full") gets its step again once others are through.
- A lane is its session's: no session stops another's, and neither do you.
  Send the owning session `pnpm verify down` instead, as you would for a
  session you park overnight with its lane up.
- `verify/admission.test.ts` fails whenever fewer than two lanes are free:
  machine headroom, not a regression.
- A session's stage 5 ends with its lane down. Before you close a session,
  check in its worktree: `pnpm verify status` answering "this worktree has
  no lane" (exit 2, its suggestion to `up` aside) is the state you want;
  a lane it still reports, the session brings down.

## The staging test account

A signed-in check needs an account that is a platform admin
(`users.role='admin'`) for `/admin/*`, a member of a sequential cohort with
seats free (org `sustainability-institute`; the iTELL Demo org has none) for
lesson progress, and in an org for `/welcome` and the org pages.
`qiushi.yan@itell.ai` is the default; its mail forwards to the user's Gmail,
so the Browser Test bot reads its magic links itself. Set the account up
before you send the check, not after it comes back blocked.

## Who can be hurt decides what you ask

The pipeline doc's § Who decides draws the lines; these are iTELL's spaces.

Do these, or let the session do them, and report them:

- anything inside a lane: its databases, servers and CMS are the session's;
- staging, a copy of iTELL that emails only the team: reads, writes
  through the app, and direct writes to its database within fair use:
  small, for a purpose, and labelled. Pull its URL with
  `vercel env pull --environment=staging` and name each row you add
  `test-<pr>-*`. A "Refresh staging from production" run wipes them, so
  check they are still there before a check relies on them;
- reads of production through the read-only role
  (`ITELL_PROD_READONLY_DATABASE_URL`).

Ask, holding only the work that depends on it:

- a write to a production database, including the CMS's content;
- the production deploy (below);
- a reply to a learner's bug report: draft it for the user to send.

A migration is no ask of its own: the merge applies it on staging and the
production deploy in production, so it waits only for that deploy. The
platform's "never self-apply a migration" (`apps/platform/CLAUDE.md`) keeps
sessions off the databases outside lanes and staging; on 10-29 three
sessions held a migration for the user that rode its merge unasked.

## After the PR: merge, staging, production

iTELL PRs carry no review bots, so stage 8 has nothing to loop over; a
person's review comments are a fix step like any other. Open a strategic
review on your own judgment for a complicated or critical change, such as
one that writes production data, adds a table or changes what every user
meets; its session verifies in a lane of its own. On 10-29 none was opened
until the user asked.

Merging is yours once the stages have run with a passed verdict at the PR
head. `merge-when-ready` has the session merge, follow the staging deploy
and check what staging shows a visitor. A change in both repositories
merges the side that answers first (`STAGING.md`). One session merges at a
time:

```bash
drive send T1@… --snippet merge-when-ready --hold itell-main
```

Every browser-based check, on staging or production, goes to the Browser
Test bot without asking the user, naming the account it signs in as. The
check lists what passing looks like exactly: the click path to the end
state (a lesson with only reading counts as done after "Mark as complete")
and computed-style values for a subtle visual change. Its writes on staging
are fine. The production deploy follows a signed-in staging check and is
the user's grant; "fix X, then deploy" is one grant, recorded with `drive
record grant`. Then send the session `recap`, and its `closeout` (the
handoff distill), one session at a time.

## The production deploy

Under the user's grant, the session that merged runs it as its next step,
before its recap, so its report says what shipped. `release.yml` promotes
what staging runs, for the platform, the CMS and the API together
(`DEPLOYMENT.md` § Releasing to production); `deploy-platform.yml` by hand
is the escape hatch, and from `main` it can ship a commit staging never ran:

```bash
gh workflow run release.yml -R learlab/itell                      # the plan only: what each system would ship
gh workflow run release.yml -R learlab/itell -f confirm=release   # ships it; migrations run in the platform's build
cd apps/platform && psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f scripts/agent-readonly-role.sql   # after a migration, under the same grant; URL from .env.production
```

A PR that adds a table classifies it in `scripts/agent-readonly-grants.sql`
before it merges: PR checks run lint only, and the staging deploy's tests
fail on an unlisted table. The report names every PR the deploy ships and
flags any gate a user meets, such as a new terms version every account
accepts again.

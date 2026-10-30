# Driving planlab sessions

Most drives are planlab batches: several `planlab-ai/main` sessions taken
from onboarding through a polished PR, its merge and release, and the
closeout.

## The design checkpoint

When a batch starts sessions whose design is not settled, the user reviews
every design before anything is built, in one report once all of them have
reached it. That is when they still steer cheaply: a design they would amend
costs a rebuild once built. A session handed over already past its design
goes straight on.

After onboarding, every such session gets the same design stage, whatever
its path, and the spec question waits until its design is in:

```bash
drive send T1@… --snippet consult-design   # astra and fable settle the design; it ends with its decisions
drive send T1@… --snippet spike-check      # next, where the design rests on an assumption reading cannot settle
```

Hold each session there: the design reply stands in for its recap, so send
no `recap`; park it (`drive park T1@… "design checkpoint"`) and leave its
block open for the user's answers. Until all have arrived or parked, message
the user only for a decision that holds a session. Then report, as SKILL.md
§ Report shapes it: per session, the design in a few lines, what the spikes
showed, and your call on a spec (`session-pipeline.md` § Choosing the path).

Ask the design questions the pipeline doc's § Who decides names, each as one
question with what it changes. List every technical choice as the default
the session will take, with any consequence for scope: technical-looking
choices are where the user has amended scope before.

Nothing goes past the checkpoint without the user's word; this outranks
SKILL.md's Continue. A drive the user scoped to design is done once this
report is sent. With their answers, per session:

```bash
drive send T1@… '/write-spec <their answers>'                  # spec: then /compact, then implement-spec
drive send T1@… '/write-spec @/tmp/t1-answers.md'             # answers longer than a line, attached
drive send T1@… --snippet implement-now '<their answers>'      # no spec: builds from the settled design
```

Then on through review to the finish.

## Who can be hurt decides what you ask

Planlab's spaces, by the pipeline doc's § Who decides. Eval, Steward, Bench
and the internal workspaces have no customer behind them (planlab
`AGENTS.md`). Do these, or have the session do them, and report them:

- **Read production:** `planlab` backstage reads and read-only SQL
  (`pl-planlab-cli`), `pl-backstage-db`, CloudWatch logs.
- **Use internal workspaces:** `loopy-os-demo`, the `planlab-dev-*` ones,
  `qiushi-lab`, the demo workspaces and the user's personal ones. Reads and
  writes there go ahead, including `planlab loopy`, `replay` and `case run`,
  and a demo check after a release.
- **Use internal systems:** file and update Bench cards, and create, rename
  and sync briefs in the handoffs repository.
- **Clean up a review branch** such as `pr-<N>-review` in the main
  checkout once its PR has merged, beside SKILL.md's cleanup.
- **Leave a Bench card's verifier unnamed:** the card closes itself after a
  quiet week. Say so under **Done without asking**.
- **A release's migration gate**, by the pipeline doc's § Who decides. First
  check whether a teammate's release already shipped what it holds
  (`pl-check-deployed`, and who ran the last `release prod`): then it needs
  no override. Name an override, what it covered and why it was safe.
- **A `#loopy` announcement**, posted by `pl-loopy-handoff-distill` § The
  announcement's rule for who it notifies, untagged where that rule says so.

A workspace is internal when PlanLab's own organization owns it; the names
above are the known ones. Some customer-looking workspaces are run by
staff, so when you cannot tell, treat it as a customer's.

Ask:

- **A write in a customer's workspace or data:** a replay or `case run`
  there, an `--as-user` support session, an `aperture` switch for a
  customer, or a backfill's `--commit` against the production database.
- **A migration gate over customer data:** a migration that drops or
  rewrites customer data or installs something that writes it, or a forced
  check. Send the session's recommendation and
  its reasoning with the ask, and say in plain words what the gate protects.
- **Production infrastructure:** taking down or resizing a tier on
  `planlab-prod`.
- **A message addressed to a person** in Slack: draft it for the user to
  send, and only once what it announces is live.

## After the PR: strategic review, merge, release

Every PR gets a strategic review once its code review is handled (stage 9),
unless the build session's report opts out on stage 9's terms and its diff
bears them out. The review session has read the whole change, so it folds
the findings in and merges; the builder's part ends when it starts. Merging
and releasing are yours unless the user says "hold merges":

```bash
drive send T1@… --snippet strategic-review-brief     # the builder writes the reviewer's prompt
drive open sr-9531 --dir ~/dev/planlab/main --goal 'Review #9531 before it merges: where its design or evidence could be wrong.' '/strategic-review 9531 @<the prompt file>'
drive send T1@… --snippet recap                      # then close T1; its branch and worktree wait for the cleanup after the merge
drive send sr-9531@… 'Fold these in.'                # once the review reports; the skill says how
drive send sr-9531@… --snippet merge-when-ready --hold release 'Its one red check is the advisory every branch fails.'
drive send sr-9531@… --snippet recap
drive send sr-9531@… --snippet closeout --hold planlab-main
```

- Once the stages the pipeline doc's § Who decides lists have run,
  `merge-when-ready` merges, releases (or confirms a release in flight
  shipped it), checks what production serves and writes the changelog,
  taking a migration gate as above. Send it by its key with `--hold
  release`, so no other session releases at once, and put what the session
  should know after the key; a hand-written merge step needs the same hold.
  PRs that touch the same code merge one after another.
- A PR that skipped its review merges from its builder. A PR whose session
  is gone gets a new session for its merge, so the merge runs where its
  checks and its report are.

# Driving planlab sessions

Most drives are planlab batches: several `planlab-ai/main` sessions taken
from onboarding through a polished PR, its merge and release, and the
closeout. When the user names the sessions or their work, drive those; when
they ask what the next batch should work on, follow
[`PLANLAB-NEXT-BATCH.md`](PLANLAB-NEXT-BATCH.md) first.

## The design checkpoint

When a batch starts sessions whose design is not settled, the user sees
every design in one report, once all of them have reached it. A session
that recommends an answer builds on it, since a night parked at its design
costs more than the rare rebuild, and only its merge waits for the user's
word. A session handed over already past its design goes straight on.

After onboarding, every such session gets the same design stage, whatever
its path:

```bash
drive send summary-decisions@… --snippet consult-design   # astra and fable settle the design; it ends with its decisions
drive send summary-decisions@… --snippet spike-check      # next, where the design rests on an assumption reading cannot settle
```

A larger UI or UX change shows its design (the pipeline doc's stage 2):

```bash
drive send reply-streaming@… --snippet emil-prototype 'Replies jump as they stream, and the final card flashes in.'   # variants on the Prototype Studio bar; it stops at them
drive send reply-streaming@… --snippet emil-finish 'The checklist variant, with the count from the ledger one.'      # on the user's pick
```

Its pick is a critical question, below: check that the preview link loads
before you send it. A change the design already settles, such as an agreed
setting, goes straight to its build.

The design reply stands in for a recap, so send no `recap`. Record each
design question it leaves the user as an ask that says what runs meanwhile,
then send the session on, by your call on a spec (`session-pipeline.md` §
Choosing the path):

```bash
drive record ask summary-decisions --question '…' --recommendation '…' --if-unanswered 'It builds as recommended; the merge waits for your answer.'
drive send summary-decisions@… '/write-spec Go with your recommendations. I answer the design questions before the merge.'   # spec: then /compact, then implement-spec
drive send summary-decisions@… --snippet implement-now 'I answer the design questions before the merge.'                   # no spec: builds from the settled design
```

Two kinds of question hold the work that depends on them, and only that
work; park the session once nothing else is left to build:

- **One with no recommendation.**
- **A critical one,** by the pipeline doc's § Who decides, whether the
  session marked it or you judge it so. It goes to the user at once, in a
  message of its own, and the session's step names it: `… Question 2 waits
  for my agreement: build everything that does not depend on it.`

Once all have
reached the checkpoint, report as SKILL.md § Report shapes it: per session,
the design in a few lines, what the spikes showed, and each design question
with what it changes for the person using the product. List every technical
choice as the default taken, with any consequence for scope:
technical-looking choices are where the user has amended scope before.

An answer that amends a design goes at once to the session that holds the
change, the builder or its `sr-` session, with what to rebuild. A merge
waits while a design question about its session is open. A drive the user
scoped to design builds nothing: park each session on its asks, and it is
done once this report is sent.

## How the user likes planlab work

- **Practical over perfect:** fix the obvious mistakes in this PR and leave
  the rest for later. Prefer a library or a dependency upgrade to
  hand-written code, and a shared package for anything both the app and
  Taodesk need.
- **A bug report** goes through `/pl-loopy-debug` against the real
  production trace.
- **Decisions** reach the user on one combined board, each with your
  recommendation.
- **Work the user hands you** starts a new session in its own worktree.
  Planlab sessions open in a Rex session of their own, apart from other
  projects.

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
  checkout once its PR has merged; `drive cleanup` leaves it.
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
the findings in and merges; the builder's part ends when it starts. It
opens on Fable, the user's choice for this review, unless they name another
model. Merging and releasing are yours unless the user says "hold merges":

```bash
drive send summary-decisions@… --snippet strategic-review-brief   # the builder writes the reviewer's prompt
drive open sr-summary-decisions --model fable --dir ~/dev/planlab/main --goal 'Review #9531 before it merges: where its design or evidence could be wrong.' '/strategic-review 9531 @<the prompt file>'
drive open sr-summary-decisions --model fable --effort xhigh …    # only when the user asks; their settings run Fable at high
drive send summary-decisions@… --snippet recap                    # then close summary-decisions; its branch and worktree wait for the cleanup after the merge
drive send sr-summary-decisions@… "F3: <the user's answer>. Fold it in."   # only to a review that left a finding unfolded for the user
drive send sr-summary-decisions@… --snippet merge-when-ready --hold release 'Its one red check is the advisory every branch fails.'
drive send sr-summary-decisions@… --snippet recap
drive send sr-summary-decisions@… --snippet closeout --hold planlab-main "If #9531's merged record has no marker for its owed read, add one on develop in a docs PR and merge it."
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
- **Red checks that are not the PR's:** when the failing tests also fail on
  develop, or sit in files the branch did not touch, the merge step says so
  and has the session attach the `emergency-merge` label and merge, with no
  ask, since `pl-land` stops at a red check it did not cause. Name the tests
  under **Done without asking**.
- **A docs pass runs before every merge**, the emergency merge included.
- **Owed reads and gated checks** run as soon as there is enough data, not
  at their deadline; when clean, go straight on to the merge.
- **The strategic review folds its own findings** when you opened it, and
  reports after the fold. Relay a finding to the user only when the review
  calls it foundational or could recommend nothing on it; that one holds the
  merge.
  Close the builder once its `sr-<PR>` session opens. The fold counts toward
  the code review's churn budget, so the merge step after it adds `If the
  review stops on churn, that's my fold: continue with --churn-ok.`
- **A builder that stops on churn before its strategic review** goes to the
  review, not to the user: open it, and have the builder's brief say where
  the fixes kept landing.
- **A read owed after the merge** closes its session once it is a marker on
  develop (`pl-loopy-handoff` § Documentation bindings, *Owed reads*), as
  the closeout step above makes sure: a PR comment alone reminds nobody.
- **A session left waiting** on people or a release posts a PR comment: what
  is left, what it waits on, and how to finish.

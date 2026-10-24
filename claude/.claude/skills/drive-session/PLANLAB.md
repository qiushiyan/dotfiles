# Driving planlab sessions

Most drives are planlab batches: several `planlab-ai/main` sessions taken
from onboarding through a polished PR, its merge and release, and the
closeout. This file holds what is planlab's own. The stages and snippet
keys are in `~/dotfiles/docs/session-pipeline.md`, and the rest of the drive
is in SKILL.md.

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
no `recap`; park it (`drive park T1@… "design checkpoint"`) and leave its block
open for the user's answers. Until all have arrived or parked, message the
user only for a decision that holds a session. Then report, as SKILL.md
§ Report shapes it: per session, the design in a few lines, what the spikes
showed, and your call on a spec. A spec pays where the change is
infrastructure or runtime with a large blast radius, or its design has
decisions worth fixing in writing (`session-pipeline.md` § Choosing the path).

The user steers on scope, on what the product does for the person using it,
and on who gets told what; on technical choices they defer to the session.
So ask about the first three, each as one question with what it changes;
list every technical choice as the default the session will take, with any
consequence for scope, so the user can still overrule one. Keep the
technical-looking choices in the report too: they are where the user has
amended scope before.

Nothing goes past the checkpoint without the user's word; this outranks
SKILL.md's Continue. A drive the user scoped to design is done once this
report is sent. With their answers, per session:

```bash
drive send T1@… '/write-spec <their answers>'                  # spec: then /compact, then implement-spec
drive send T1@… '/write-spec Read /path/answers.md for my answers'   # answers longer than a line
drive send T1@… --snippet implement-now '<their answers>'      # no spec: builds from the settled design
```

Then on through review to the finish.

## Who can be hurt decides what you ask

Planlab's `AGENTS.md` sizes caution to who can be hurt: Eval, Steward,
Bench and the internal workspaces have no customer behind them. Draw the
same line. Do these, or let the session do them, and report them under
**Done without asking**:

- **Read production:** `planlab` backstage reads and read-only SQL
  (`pl-planlab-cli`), `pl-backstage-db`, CloudWatch logs.
- **Use internal workspaces:** `loopy-os-demo`, the `planlab-dev-*` ones,
  `qiushi-lab`, the demo workspaces and the user's personal ones. Reads and
  writes there go ahead, including `planlab loopy`, `replay` and `case run`,
  and a demo check after a release.
- **Use internal systems:** file and update Bench cards, and create, rename
  and sync briefs in the handoffs repository.
- **Docs passes:** run them when a session is ready for one.
- **Clean up a review branch** such as `pr-<N>-review` in the main
  checkout once its PR has merged, beside SKILL.md's cleanup.
- **Leave a Bench card's verifier unnamed:** the card closes itself after a
  quiet week. Say so under **Done without asking**.

A workspace is internal when PlanLab's own organization owns it; the names
above are the known ones. Some customer-looking workspaces are run by
staff, so when you cannot tell, treat it as a customer's.

Ask, holding only the work that depends on it:

- **A write in a customer's workspace or data:** a replay or `case run`
  there, an `--as-user` support session, an `aperture` switch for a
  customer, or a backfill's `--commit` across the fleet.
- **A gate a release puts in front of a person:** a migration-gate
  override or a forced check. First check whether a teammate's release has
  already shipped what the gate holds (`pl-check-deployed`, and who ran the
  last `release prod`): a gate that no longer holds anything is not asked.
  Send the session's recommendation and its reasoning with the ask, and say
  in plain words what the gate protects.
- **Production infrastructure:** taking down or resizing a tier on
  `planlab-prod`.
- **A message to a person:** Slack, a `backstage loopy announce` post. Draft
  it for the user to send, and only once what it announces is live.
- **Text the user owns,** such as a decision-ledger entry.

## After the PR: strategic review, merge, release

A change that is complicated or critical to production behaviour gets a
strategic review in a fresh session before it merges; open one on your own
judgment, and lean towards more rather than fewer. The build session writes
the reviewer's prompt, a new session runs the review, and that review
session folds the findings in and merges: it has read the whole change and
holds the fixes.

```bash
drive send T1@… --snippet strategic-review-brief    # the builder writes the reviewer's prompt
drive open sr-9531 --dir ~/dev/planlab/main '/strategic-review 9531 Read <the prompt file> for where to look hardest'
drive send sr-9531@… 'fold these in'                 # once the review reports; the skill says how
```

Merging and releasing are yours in a planlab batch unless the user says
"hold merges". Have the session that last worked on the PR merge it (its
review session, where it had one) once a strategic review cleared it or its
findings are folded in (or the change is docs-only), its required checks are
green, and its code review is handled; merge PRs that touch the same code
one after another. A finding the review calls
foundational, or a design objection the session rebutted, goes to the user
first. `merge-when-ready` has the session merge, release (or confirm that a
release already in flight shipped it), check what production serves and
write the changelog, stopping at a migration gate; one session at a time:

```bash
drive send sr-9531@… --snippet merge-when-ready --hold release
```

Then send the session that merged its `recap`, and its closeout
(`--snippet closeout --hold planlab-main`), one session at a time. A PR whose
session is gone gets a new session for its merge, so the merge runs where
its checks and its report are.

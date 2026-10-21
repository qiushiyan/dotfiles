# Driving planlab sessions

Most drives are planlab batches: several `planlab-ai/main` sessions taken
from onboarding to a polished PR, and often through merge, release and
closeout when the user hands those over. This file holds what is
planlab's own. The stages and snippet keys are in
`~/dotfiles/docs/session-pipeline.md`, and the rest of the drive is in
SKILL.md.

## The design checkpoint

When a batch starts sessions whose design is not settled, the user reviews
every design before anything is built, in one report once all of them have
reached it. That is when they still steer cheaply: a design they would amend
costs a rebuild once built. A session handed over already past its design
goes straight on.

After onboarding, every such session gets the same design stage, whatever
its path, and the spec question waits until its design is in:

```bash
$S/snippet consult-design "$SESSION_DIR" > $F   # astra and fable settle the design; it ends with its decisions
$S/snippet spike-check "$SESSION_DIR" > $F      # next, where the design rests on an assumption reading cannot settle
```

Hold each session there. Until all have arrived or parked, message the user
only for a decision that holds a session. Then report, as SKILL.md § Report
shapes it: per session, the design in a few lines, what the spikes showed,
the decisions it needs with its recommendations, and your call on a spec.
A spec pays where the change is infrastructure or runtime with a large
blast radius, or its design has decisions worth fixing in writing
(`session-pipeline.md` § Choosing the path).

Nothing goes past the checkpoint without the user's word; this outranks
SKILL.md's Continue. With their answers, per session:

```bash
$S/send-turn ID '/write-spec <their answers>'                 # spec: then /compact, then implement-spec
$S/snippet implement-now "$SESSION_DIR" "<their answers>" > $F  # no spec: builds from the settled design
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
  override or a forced check. Send the session's recommendation and its
  reasoning with the ask.
- **Production infrastructure:** taking down or resizing a tier on
  `planlab-prod`.
- **A message to a person:** Slack, a `backstage loopy announce` post. Draft
  it for the user to send.
- **Text the user owns,** such as a decision-ledger entry.

## Merges and releases

The finish is a polished PR, and its merge and release are the user's. They
become yours only when the user says so about merging or releasing; "drive
these to the end" means to the polished PR. Once they are yours, have each
PR's own session merge it when its checks are green and its code review is
handled, merging PRs that touch the same code one after another. Release
once for the batch through one session, then send the closeouts one at a
time. A PR whose session is gone gets a new session for its merge, so the
merge runs where its checks and its report are.

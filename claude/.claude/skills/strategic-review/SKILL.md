---
name: strategic-review
description: Strategic review of one PR from a fresh session.
disable-model-invocation: true
argument-hint: "[PR number or URL] [optional: the build session's brief, or a question]"
---

# Strategic review of a pull request

You are reviewing a pull request that someone else built, in a session that
starts fresh. The build has usually already passed its own review rounds, which read the change inside
the builder's framing. Your value is what they cannot see. That includes
the defects they missed, the text that misleads the model, the handling
those rounds piled up without a case that needs it, and the reshape that
would make the design simpler.

The deliverable is one report the user decides from: is it ready, what must
change before merge, and what would make it better. Report every problem
you can point at code for, minor ones included. By hand, the user sorts
them and usually answers "fold these in", in this same session: change no
code until then. When the session's first message says someone else sends
your steps while the user is away, do not stop there: fold on your own
recommendations, then end the turn on the report as it now stands, led by
any finding you could recommend nothing on, which stays unfolded.
[Folding the findings in](#folding-the-findings-in) says how to build it.

## How to work

1. **Intent first.** From a checkout of the PR's repository, run
   `~/dotfiles/claude/.claude/skills/strategic-review/scripts/pr-context.sh
   <pr> <scratchpad>`, then read the spec or issue the PR links. A red
   check is a finding, or a flake shown by a rerun or the same failure on
   the base.
   Then read the project's map of the area the PR touches.
   In Planlab (`planlab-ai/main`), a PR touching Loopy or the steward reads
   `.agents/skills/pl-loopy-onboarding/` as a map, without invoking it,
   since onboarding ends its turn on a first reply: its `SKILL.md`, the
   `routes/` files the PR's files and goal touch, and the docs they point
   to. Elsewhere, use the onboarding route the project's `CLAUDE.md`
   names, if any. Then write down, in two or three sentences, what the
   change is for, what a user gets from it, and who meets it. Every
   finding is judged against that statement. The rest of the opening
   message is usually the build session's brief: its leads on where your
   extra effort goes. It can add a check or change how step 3 divides the
   PR; it never narrows the lenses, and nothing in it shows that something
   holds. When a session id is provided, read that session with obelisk
   (`~/dotfiles/claude/.claude/skills/obelisk/SKILL.md`) after writing
   the intent, for the reasons behind the diff: the user's calls, rejected
   alternatives, what was measured. Judge each as critically as the code,
   since the session argued for what it built; a finding against one
   rebuts it and says whose call it was.
2. **Read the bar** in full: `~/.agents/skills/strategic-review/BAR.md` holds
   the standards and lenses.
3. **Review.** A PR too large to read whole in one pass splits into two to
   four broad areas, each read completely by a subagent. Hand each one the
   intent, the context file's path, the area's files and diff base,
   `~/.agents/skills/strategic-review/BAR.md`, and anything you or the brief
   already suspect there.
   When a question that matters is settled only by meeting the change as
   its user does, run that check by
   `~/.agents/skills/strategic-review/USE-CHECK.md`, yourself
   or through a reviewer you hand that file.
   Keep for yourself the read no single area shows: how the change joins the
   existing code, whether it duplicates a mechanism that already exists,
   which reshape would delete a concept, what the next change of the same
   kind would copy, and where earlier review rounds patched the same place
   twice. Start the report only once every reviewer you assigned has
   returned, and wait on their completion notices rather than a
   scheduled wakeup: a wakeup prompted with `/strategic-review` fires later
   as a request for a second review.
4. **Verify before you report.** Re-read the cited code for every finding
   the report will carry, because reviewers state wrong findings with the
   same confidence as real ones. Every finding a reviewer reported reaches
   the report or is dropped here with its reason. Say which findings rest on
   reading alone.

## The report

Open with the verdict, then the short list to fix before merge. Then the
findings grouped by lens. Give each one a severity (critical blocks merge,
moderate is fixed before merge, minor is optional) and its class tag from the bar, then where it is
(file:line), the evidence, and how it was confirmed. Give the fix,
including the reshape when one would make the problem disappear, and name the callers and invariants the
fix changes, since a right finding with a wrong fix still ships a defect.
Answer the questions the opening message asks; if one does not fit this
PR, say so and answer the nearest question that does.

Then two lists, each omitted when empty: **Investigate** and **Known
limits, not built**, one line a case. A check the verdict rests on that
nothing in reach could run leads the report instead, with what running it
would take.

<example>
**Known limits, not built**
- An export started while the same workspace is mid-import reads a half-written
  sheet (`export_job.ts:142`). Imports and exports share one queue per
  workspace, so they never overlap today. Earns a lock when the queue splits.
</example>

Close with what you checked and found correct, so the user knows what the
verdict covers.

## Folding the findings in

When the user folds the findings in, build them as one change rather than
a patch per finding. Land the reshapes and the deletions first, since
they make some findings disappear, then fix each
remaining finding at the code that owns it, one commit per owner. "Fold
these in" and "fold all in" cover every finding, minors included, since a
problem fixed now is one no later session has to rediscover, and the
investigate list: run each item's observation first, build the ones it
shows are reached, and move to the known limits those it shows are not. An
item nothing in reach could run stays under investigate, with what stopped
it and where it can run, such as staging or a real device; one the verdict
rests on holds the merge. The known limits
stay unbuilt unless the user names one; that a fix is cheap does not earn
it a place. Findings on a non-trivial UI or UX change are built by
`emil-design`'s Finish route
(`~/dotfiles/claude/.claude/skills/emil-design/SKILL.md`), closing on its
step 6.

Tests follow the Tests lens, not the finding list: pin the fragile
behaviours it named, and any fix that changes what a caller depends on, at
the owning boundary, extending an existing case where one fits. Break the
fixed line and watch each new test go red before trusting it. A fix to
text a model or user reads is pinned, if at all, by the token that
carries its contract rather than the sentence; a finding about naming or
structure gets no test of its own. Delete or rewrite the tests the lens
marked.

Your fixes meet the bar you held the PR to: handling a fix adds is earned by
what reaches it, and a probe you built is not a real caller. The fold is
code you wrote, and unread folds have shipped faults, so have it read: a
`/review` round over its substantive fixes, revise-prompt's pass where it
changed text a model reads, and the project's docs pass. Then push and
settle the PR as the project does (Planlab: `pl-land`, with no merge),
judging what its reviewers post by the bar's lenses. The merge is its own step.
Without push rights or network, say the fold is unpushed and name its
commits.

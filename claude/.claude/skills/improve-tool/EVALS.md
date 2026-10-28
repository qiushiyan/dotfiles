# Replay a finding through skill-evals

`~/dev/skill-evals` (private, on both machines through twin) replays a skill
headless against chosen revisions; its README covers cases, fixtures, and
commands, including which judge grades by default. Use it when a finding
reproduces within one headless session, from the request alone or with one
scripted reply. Rollouts send the fixture's content to Anthropic for the
agent and the default judge, and to OpenAI for a `codex:<model>` judge or a
tool that consults codex. Name them in the pass's disclosure.

## A finding becomes a case first

Before editing, record the commit the skill is at; that sha is the case's
`red`. Write the finding as a case: the request, the source session, and
what passes and fails, stated as things a transcript shows. Include the
outcome, so a run cannot pass on process alone. If a case already tests the
behavior, tighten it; a case that passed the failure you found is itself a
finding. Then run every case of the tool at `red` and at `WORKTREE`, so each
has a baseline. Set the run count by how often the failure shows: a mistake
seen a few times a week needs more than three runs. To keep a candidate out
of live sessions until it passes, edit a copy and pass its directory as the
revision.

Before spending runs on a new case, run `skill-eval calibrate` on it (a
reader arm that may only read, and one rollout at `red`), unless reading is
the tool's whole method, as in a review. A reader that passes, or a `red`
that passes, means the case cannot tell the conditions apart; make the
outcome depend on what reading cannot reach. A question about phrasing, or a
skill against none, is a set of arms (`arms.json`). Every arm set needs a
control: an arm marked `hints`, whose request carries the case's
`## Control`, naming where the outcome lives. Without it, zeros cannot say
whether the arms missed the outcome or the rig hid it.

A regrade can move a check either way, so use `--judge-passes 3`, a blind
`rank` for quality, and `findings` against the whole answer key. Read an
arm's difference from the baseline by the report's interval; one spanning 0
is noise at that many runs. Read whether an arm took its treatment from the
counts `tool.json` `track` adds.

## Reading the result

- **Evidence for the edit:** the earlier revision fails the case, the edit
  passes it, and no passing case starts failing. Report per-case counts, not
  one verdict.
- **Earlier revision passes too:** the harness did not reproduce the mistake
  at this run count. Say so rather than claim the edit helped. The rule
  becomes a deletion candidate once enough runs and the live history both
  show the model no longer makes the mistake.
- **Deleting a rule:** run its cases against a copy of the skill without it.
  Compare cost as well as verdicts, since a rule can stop guarding
  correctness and still save a round.
- **After a model upgrade:** rerun the tool's cases at HEAD to see which
  rules the new model still needs.

After committing, set the case's `green` to the commit.

## Work that one session cannot show

A tool whose value shows only on real work, a finding that needs several of
the user's turns, or a tool with no fixture, replays merged PRs
(`docs/pr-replay.md` in the repo: the answer key, a fixture recipe, the
case, arms). The replay head is
the commit the PR was at when the tool was asked for. The answer key is what
its reviews, bots, CI, and later fixes found at that head; mark which defects
the stack can reach.

A replay that needs the project's running stack runs on the owner's machine,
beside their other sessions. An old head's tooling meets today's shared
state there: its cleanup can take another checkout's resources for orphans,
and an agent blocked by a format it cannot read routes around the block. So
give the live tool a read-only `preflight.check` that refuses while shared
state looks like the replay's own, and a `forbid` list denying the commands
that redirect or destroy it.

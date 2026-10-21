# TabType snippets — evidence log

One entry per mining pass over how the snippets are used; counts are written
so the next pass can re-run them.

## 2026-10-04 — what is expanded, and what is typed by hand instead

Session `77644487`. Its scratchpad is temporary; the query scripts survive in
that session's transcript as the heredocs `fp.py`, `gen.py`, `q5.mjs` and
`q6.mjs`.

**Corpus.** Laptop obelisk index: Claude user turns 2026-06 → 10-04 (12.7k),
Codex 2026-05 → 10-04 (4.7k). The mini's index over ssh: 09-25 → 10-04 (700
Claude turns; sessions moved with `claude-tomini` appear in both).
`~/.config/tabtype/history.json`: 09-27T21:55Z → 10-04 only; a test run reset
it (`test:item-*` rows), fixed in tabtype `cd8ff20`.

**Predicates.** A use is a user turn (`role='user'`, `content_type='text'`,
not meta, not sidechain, not a continuation summary) containing the first
line, to 80 characters and with a leading `/command` stripped, of any
committed version of the snippet's `expand`; the longest match wins. A
slash-led snippet is stored twice (the paste and the `<command-name>` row), so
sessions are the unit, not turns. Hand-typed patterns: Claude turns since
08-05 (8,045 turns, 950 sessions), text cut at the first snippet fingerprint,
turns over 5k characters dropped, matched case-insensitively against:

```text
end to end      implement .{0,40}end[- ]to[- ]end|build .{0,30}end[- ]to[- ]end
no poll         no poll|handle (review )?once
closeout        pl-loopy-handoff-distill\s+(branch )?merged
consult         (consult|consultation)( round)? with codex|codex to settle
spikes          (run|do|build|write|try) (some |a few |a |local |quick |throwaway )*spikes?|spike (it|this|first)
plain terms     plain (terms|english|language)|simple terms|layman|explain .{0,30}(simply|plainly)
defer docs      (defer|skip|no) doc(s|umentation)? updates?
```

**Validation.** For 09-27 → 10-04 the fingerprint counts against TabType's
own counter: `implement-spec` 10 vs 10, `review-verify` 2 vs 2, `prompt-check`
7 vs 8, `loopy-review-verify` 15 vs 13, `loopy-prompt-check` 9 vs 8. Mid-body
phrases of the stopped snippets show no later use than the first-line count.

**Limits.** Expansions into non-agent apps are invisible before 09-27.
Planlab's `.tabtype.local.toml` is gitignored, so earlier wordings of the
`loopy-*` keys are undercounted. "Never" means never since May/June.

| finding | evidence | verdict |
|---|---|---|
| 13 keys never expanded | 0 hits, first line and mid-body | removed |
| the hand-carried plan/review loop is dead | 10 keys, last uses 06-22 → 07-31; `/consult` 148 and `/review` 151 sessions in September | removed |
| 8 one-offs | at most 4 uses each, none after 08-07 | removed |
| `write-spec` | 47 uses / 43 sessions, last 08-30; `/write-spec` skill 63 sessions in September | removed on the user's word |
| `compact-for-impl`, `compact-for-review` | 51 / 23 (last 09-16) and 38 / 28 (last 08-21); about 40 laptop sessions ran a bare `/compact` since 09-21. Why the staged form stopped is unknown. | removed on the user's word |
| `handle-review` | 48 / 43, last 08-01; `/pl-handle-code-review` 108 sessions in September, 26 laptop + 14 mini of them typed as "handle (review) once, no poll" | global key removed; planlab-local `loopy-handle-review` added (wording: the revision pass below) |
| `think-holistic` | 101 / 83, last 08-30; no replacement identified | kept on the user's word |
| `loopy-closeout` | last 09-23; "/pl-loopy-handoff-distill merged (and deployed)" typed in 18 + 8 sessions since | shrunk to the typed form |
| "implement end to end" with no spec | 90 sessions in 60 days, 23 + 5 since `implement-spec` came into use on 09-21 | `implement-now` added; "defer doc updates" (64 sessions) left to `rules/docs.md` |
| `consult-codex` | 0 uses since it was added 09-21, against 19 + 8 sessions phrasing the same ask by hand; the user had not known it existed | reshaped: slash-led, cursor at the end |
| standalone spikes | "run some spikes" in 30 sessions / 36 turns over 21 days; 30 turns ask to prove an approach, 6 a diagnosis, 6 name a consult | `spike-check` added; `consult-verify` (2 uses, 09-01) removed |
| consult, then build unless a decision is the user's | 8 laptop + 2 mini sessions, 09-27 → 10-04, voices codex and opus | `consult-then-build` added beside `consult-codex`: the two differ in where they stop |
| "plain terms" | 58 sessions in 60 days, 6 since 09-21 | no snippet; watch |

**Revision pass** over every kept snippet against the prompt-engineering
rulebook, with one cold reader on five scenarios.

- `think-holistic`: opens on the task and the write-up's order in place of a
  bolded "don't"; the preparatory-refactoring caveat moved from the tail into
  step 4; step 5 asks for approaches that differ in kind, per the usage lesson
  "the alternative you ask for is the alternative you get" (measured on the
  pickup gate, not on this snippet); "Interview me" became "Ask me" in one
  write-up, where the cold reader could not tell one turn from two.
- `review-verify`, `spike-check`: name the spike skill's moment and leave the
  discipline, the count and the report shape to the skill, which the snippet
  had restated. `spike-check` overrides the skill's "take the costliest one"
  in so many words, because the typed asks were plural.
- `consult-then-build`: one round; stops only on what a default cannot
  settle. The first wording stopped on any "product or direction fork", which
  the cold reader read as the unanswered questions it was meant to default,
  and asked for "open questions with defaults", which the consult brief's
  "prose, not a questionnaire" forbids.
- `loopy-handle-review`: says the skill's own single-round trigger ("owns the
  loop and will re-invoke"). "Once, no poll" was followed by a wait call in 5
  of 31 turns since 09-10 (upper bound: any `sleep` counted), against 217 of
  272 for the bare command.
- `loopy-prompt-check`: the rulebook path is home-relative, so the laptop's
  and the mini's copies can be the same text.

Keeps, with reasons. `implement-spec` reads awkwardly ("mental model on") but
its first 80 characters are the session board's match key, and the change
would be cosmetic. `prompt-check` repeats the rulebook's "short, with an
example" because the user asks for it beside the pointer every time, and its
"no literal tests" is a line the user drew. `elaborate-questions` echoes
`think-holistic`'s question lanes on purpose: it fires in sessions that never
saw that snippet. `loopy-closeout` and `consult-codex` are the user's own
words to a skill that owns the rest. The numbered steps in `think-holistic`
stay because the reading genuinely comes first.

**Not done.** `tabtype/CLAUDE.md` § Invariants still governs the removed
families.

**Next pass compares**, from `history.json`, four weeks of counts per key:

- `implement-now`, `loopy-handle-review`, `loopy-closeout`, `consult-codex`,
  `consult-then-build` and `spike-check` each expanded in at least three
  sessions, and the hand-typed counts for the patterns above lower than this
  entry's. A key still at zero while its phrase is still typed has the wrong
  wording or the wrong home; revise or remove it.
- Any removed key retyped from memory or pasted from Git history is a removal
  to reverse.

## 2026-10-05 — closing a tool's branch out is typed onto `/update-docs`

Session `dec38617`; the queries are the `obq-dec38617-*.mjs` heredocs in its
transcript.

**Corpus.** Laptop obelisk index, Claude user turns 2026-08-05 → 10-05
outside planlab and itell (`project NOT LIKE '%planlab%'`, `'%itell%'`,
`'%worktrees-main-%'`), not meta, not sidechain, not a continuation summary.
The mini's index was not read.

**Predicates.** An `/update-docs` session holds a turn with
`<command-name>/update-docs`. A closeout tail is that turn also matching
`merge`, `install` or `push`, case-insensitively: an upper bound, since "I
will merge afterwards" matches too. A typed merge is a turn under 400
characters with no command, matching `merge%main` or `merge back`. A typed
cleanup is a turn under 400 characters matching `clean%branch`,
`clean%worktree` or `delete%branch`.

| finding | evidence | verdict |
|---|---|---|
| the closeout rides on the docs pass | 13 of 60 `/update-docs` sessions carry a closeout tail, all 09-21 → 10-05, across claude-steps, headroom, envoy, tabtype, twin, slackkit, cout, brief and dotfiles: "update docs and merge back into main", "sync and merge into main and install" | `closeout` added, led by `/update-docs` |
| the merge is also typed bare | 7 sessions | covered by `closeout` |
| branch and worktree removal is a second, later ask | 6 sessions / 7 turns, e.g. "cleanup merged branchs and worktrees for this repo" | folded into `closeout` as its last step |
| review, then the closeout, as one ask | 0 sessions typed it; one (headroom, 10-01) asked for the merge and install first and the review after | `review-then-closeout` added on the user's word |
| `twin sync` in a closeout | 0 typed; the command is days old | named in both snippets, where it replaces "install" |

**Wording.** Both snippets carry the order and the stops as four numbered
steps, and leave the docs pass, the review round, a conflict, the install and
the removal to `update-docs`, `review`, `resolving-merge-conflicts`,
`twin sync` and `gwt remove`. One cold reader played five scenarios (a linked
worktree, work on main, a conflicting merge, a review with and without a
design objection); what it changed:

- The removal runs from the main checkout: `gwt remove` refuses the worktree
  it is run from, and the first wording's "a refusal means keep it" would
  have kept every branch a session stood in. It stays last because the
  session's own directory goes with it, so the sync's status block carries a
  local-only line for the branch, which the step names.
- A conflict is resolved, not a stop: `resolving-merge-conflicts` says
  "always resolve", and the first wording contradicted it. A failing check
  stops with the merge unpushed.
- The review variant keys its stop to the review skill's report opening on
  "nothing needs you". A design objection the session rebutted also stops
  it, which the skill alone would not; minors are fixed and round 2 runs
  first when the skill calls for it.
- The docs plan's gated items are approved in advance, on the user's word,
  where the project's bindings allow them (claude-steps keeps shipped specs
  as build records), except a doc/code disagreement settled by changing the
  described design.
- `twin sync` is told its target: bare, it syncs every repository.
- Work committed on main gives `update-docs` an empty diff, so the snippet
  names the range: this session's commits.

Keeps. "One of my own tools … no PR" changed nothing for the cold reader in a
tool's repository; it is there for a paste in planlab, which was not played.
The end state in each opening sentence is what the reader reported against
when the mini was unreachable.

TabType's checkout holds both keys again in `~/dev/tabtype/.tabtype.local.toml`,
replacing the global ones there: step 3 is the per-release procedure in its
`docs/releasing.md`, since `twin sync` does not cut a release. The file is
gitignored and exists on the laptop only.

Not tested: a paste in a live session, and whether a session survives the
removal of the worktree it was started in.

**Next pass compares**, from `history.json`, four weeks of counts: `closeout`
expanded in at least three sessions and the closeout tails on `/update-docs`
lower than 13; `review-then-closeout` expanded at all. A key still at zero
while its phrase is typed has the wrong wording or the wrong home.

## 2026-10-15 — the build session writes the strategic review's opening prompt

Session `mac:9f01709a`; the evidence is the strategic-review skill's
evidence log, 2026-10-14 entry
(`claude/.claude/skills/strategic-review/EVIDENCE.md`).

**Why the key exists.** The user ends a large build by asking the session,
in their own words, what the coming strategic review should look at. A
replay of four PlanLab PRs measured the answer itself:
- The build session was forked at the moment each review opened, and its
  paragraph was handed to the reviewer.
- The paragraph found 3.9 of the 18 checked defects the real reviews had
  missed, against 1.9 for the bare `/strategic-review <PR>`.
- It was the cheapest arm, with no consult round.

**Wording.**
- The snippet asks for the prompt itself: one fenced block, opening with the
  slash command, so it pastes as is.
- It carries the four kinds of doubt the replay's briefs held: the
  behaviours that cost most if wrong, the parts the builder is least sure
  of, what is unmeasured, and lessons to absorb before merge.
- It asks for no reassurances, under the Independent judgment invariant.
- No cold reader or live paste has tested it.

**Next pass compares**, from `history.json` and the strategic-review
sessions:
- `strategic-review-brief` expanded in at least three sessions;
- briefed reviews against bare ones, by findings and by what later rounds
  still find.

A key at zero while the request is still typed by hand has the wrong wording.

## 2026-10-17 — the light path's build stops at its report

Session `mini:e0ebda78`, an `/improve-tool` pass over the agent workflow set
against Felix Rieseberg's "How to be more ambitious" (2026-10-13), whose Depth
section asks for an outside judge instead of the model judging itself. The
ledger stayed in that session's scratchpad.

**Corpus.** Obelisk on the mini only; the laptop was unreachable. A use of
`consult-then-build` is a user turn containing `run a consult with astra, one
round`: 7 sessions, 2026-10-14 → 10-15, 6 planlab and 1 claude-steps. The
window runs from the snippet to the next real user turn.

**Observed.**
- **No review before "done".** None of the 7 builds ran a review round before
  reporting. 6 drove an instrument: the running stack in 5, a test against the
  old code in 1.
- **The review came next anyway.** The user's next turn asked for one in 5 of
  7, and 6 of 7 had one eventually.
- **It found something every time.** All 6 planlab builds drew review findings
  after being reported done, criticals in two:
  - #9036 (`fcf8ab0b/9bc23b1b`): an answer split across a transaction boundary.
  - #9081 (`8513072d/6fe53425`): joins that never finished looked finished.
- **One build went past its stage.** #9033 (`ad5f78fc/8da71859`) opened a PR,
  ran the code-review loop and reported "🟢 PR #9033 has finished its automated
  review and is ready for you to merge … nothing needed fixing", while noting
  that Codex and cursor-bugbot never reviewed it. The cold review the user
  asked for next found tokens opened to grading and stored images, patches and
  prompts.
- **The personal-tool build** (claude-steps, `a232c685`) closed out with no
  review.

**Not the cause.** The code-review loop's report of 10-04, "the merge is your
call" on a red CI (#8447, `d4cdf757/df5e2bca`), was fixed in planlab #8931
(10-12), which reads CI on the PR head. #9033's report followed that loop's
contract; the gap is the stage the build skipped.

**Changed** (the user's decision). Both keys, global and planlab, end:
"Stop at the report: the review comes next, so don't open a PR or call the
branch ready." The global key is `b12b0f2`; planlab's gitignored
`.tabtype.local.toml` carries the same line and was live from 10-17.
Rejected: folding `loopy-review-verify` into the snippet. It would save the
turn the user sends after 5 of 7 builds, but it changes the stage structure
the pipeline and drive-session follow.

**Not tested.** No replay: replaying this snippet means a whole build on the
live stack. No cold reader.

**Next pass compares** light-path sessions after the line went live (planlab
from 10-17; the global key once this branch reaches main):
- a PR opened or "ready" claimed before any review round (1 of 7 before);
- the user's next turn after the report (a review in 5 of 7 before).

Revise if sessions now stop short of work the user expected done, so that the
next turn is more often "continue" or "open the PR" than the review itself.

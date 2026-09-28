# prompt-engineering — evidence log

One entry per mining pass over the sessions that read or invoked this
rulebook; counts are written so the next pass can re-run them. Passes run
under `improve-tool`; queries are obelisk scripts over `tool_calls` reads of
the file and user turns naming it.

## 2026-09-24 — upstream sync: empty delta

`writing-for-agents` remains at folder hash
`ad2925850efb8973a72d2e666f7a975f9a2d4a9b`, the fold baseline. The global
Skills CLI 1.7.0 update and an independent GitHub tree check agree. Nothing
to graduate or reclassify. The tracked pointer check found only
skill-mechanics routes and ownership guidance; the rulebook body is unchanged.

## 2026-09-15 — upstream sync: empty delta

`writing-for-agents` remains at folder hash
`ad2925850efb8973a72d2e666f7a975f9a2d4a9b`, the fold baseline. The global
Skills CLI update and an independent GitHub tree check agree; installed
files match the upstream blobs. Nothing to graduate or reclassify.
The tracked pointer check found only skill-mechanics routes, ownership
guidance, and historical evidence; the rulebook body is unchanged.

## 2026-09-04 — first pass: the rulebook itself is a prompt

Corpus: all time, self excluded. Signatures: reads = `tool_calls.name='Read'
AND file_path LIKE '%skills/prompt-engineering/SKILL.md'` or the same path
in a Bash `input_json`; invocations = `messages.skill IN
('prompt-engineering','writing-for-agents')` or user text LIKE
`%skills/prompt-engineering/%`, `%skills/writing-for-agents/%`,
`%/prompt-engineering%`; window = invocation → next non-sidechain user turn,
Edit-row delta = Σ len(new_string) − len(old_string); job population =
sessions with Edit/Write under `/.claude/skills/`, `CLAUDE.md`, `AGENTS.md`,
tabtype `config.toml`, `.claude/rules/`, `.claude/agents/`, `/prompts/`; rule
use = assistant text in invoking sessions LIKE each defect or lever name.
Seed: the user — "this document is essentially a prompt in itself … a
centralized, very high-quality, transferable reference … concise and
informative"; the 08-31 vision on record (`39f2bf85`): goals, conventions and
constraints, not procedure.

Usage shape: SKILL.md read 134× / 76 sessions (since 06-26); invoked by
absolute path 184 / 130, by `/prompt-engineering` 128 / 70;
writing-for-agents read 119 / 61, by path 78 / 57, by slash 1 / 1;
`references/before-after.md` 1 / 1 (08-02); `SKILL-MECHANICS.md` 37 / 28;
`usage-lessons.md` 35 / 10; planlab `docs/loopy/prompting-guide.md` 167 / 60;
`references/fable-prompting-guide.md` 0. 233 invoking sessions, 73
re-invoked in-session. Job population 201 sessions, 55 read any rulebook.

| friction | count | reading | verdict |
|---|---|---|---|
| the pass lengthens what it reviews; user asks concise every time | 96 / 147 edit windows net longer, 20 shorter (claude sessions); skill files 51 / 69 longer; "concise but informative" in 13 prompts / 7 sessions + 7 more this window | observed; cause inferred: ~20 of 25 defects prescribe an addition, 3 a cut, no deletion procedure | user's: short is the usual result of better, never a hard rule — the philosophy paragraph, cut-before-add in the pass, done-when "usually shorter" — **instructions** |
| reading stack ~13k words in 4–5 files | reads above | observed; cost inferred | user's: consolidate; two goals — one high-quality transferable reference, low overhead to read — folded into one 2.3k-word file — **instructions, shape** |
| most of the rulebook unused | 9 / 25 defects in ≤ 11 sessions; before-after.md 1 read | observed | assumed, reversible: lens trimmed to the applied entries; before-after deleted, cut-vs-transform inline |
| both rulebooks always asked for together | standing paste; `/writing-for-agents` alone 1 / 1 | observed | user's: fold; writing-for-agents kept for SKILL-MECHANICS only — pointers in improve-tool, lessons/CLAUDE.md, agent-tooling/README, docs/agent-skills.md |
| first pass does not land | 73 / 233 re-invoked | observed | the pass's done-when: read once more as one whole, cold |
| 73 % of model-facing edits without a rulebook | 146 / 201 | inferred | user's: leave discovery explicit — no change |
| Fable guide not in the stack | 0 reads | observed | user's: absorb the transferable lessons — the bar's re-ground, give the reason, grounded progress, pause rule, no reasoning-echo |

Next pass should measure, after 2026-09-04: Edit-row delta sign per window
(target: shorter or zero in most); re-invocations per invoking session; rule
use against the trimmed lens (a rule named in < 5 sessions is a cut
candidate); reads of `SKILL-MECHANICS.md` after the fold (the only reason
writing-for-agents is still reached); whether the planlab house guide's
"pair with /writing-for-agents" line was updated.

Cold readers (revision route over `handoff/pickup/build.md` + `consult/DIAGNOSIS-BRIEF.md`;
authoring route, a new user-invoked skill): fixes in `260955b`. Goal review
(codex, cold, `~/.local/state/envoy/jobs/dotfiles-4f711dad/20260904-143102-review`,
3 min): partly landed — centralization and philosophy achieved; two defects
fixed after it: the bar's truth-claim rule mandated a test for any claim
while step 5 pinned only where a harness exists (one rule now: verify at the
source, pin the load-bearing ones where a harness exists); the no-op cut had
no evidentiary test (now model-relative, settled by running the document).
Design objection open for the user: re-ground-the-human and pause-only-where-
needed are runtime policies for agents that act or report across turns, not
universal rules for tool schemas or errors — move them under the Instructions
surface with that trigger.
Decided by the user: moved — both policies now sit under the Instructions
surface, triggered on "an agent that acts or reports across turns".

Fold baseline for the upstream sibling: `writing-for-agents` at folder hash
`ad2925850efb8973a72d2e666f7a975f9a2d4a9b` (lockfile `updatedAt` 2026-08-29),
absorbed in `bfb4b83`. The sync procedure is `docs/agent-skills.md` § "The
rulebook and its upstream sibling"; the next sync records its hash and
per-hunk verdicts here.

## 2026-09-08 — second pass: the shape of a document

Corpus: all time, self excluded, same invocation signatures as the first
pass. Post-fold window 09-04 → 09-08: 51 invocations (45 by path, 6 slash).
Structure ask = invoking prompt (claude, incl. the writing-for-agents
pointer) LIKE `%structur%` OR `%formatting%` OR `%header%` OR `%mental
model%`: 95 / 389 prompts, 71 / 181 sessions — an upper bound, since the
predicate also matches quoted briefs; the phrasing recurs verbatim
("structures, clear instructions, mental models, formatting and not verbose
text", `e8b530f4/1d4896ad` 09-07; "minimal and clear formatting that
contributes to clear instructions", `b5f5e59f/3c6935fb` 08-26). Skill
openings read statically: first non-heading body line of every SKILL.md,
dotfiles 47 and planlab 50. Web: the platform best-practices page, the
Fable 5 / 5.1 / Opus 5 model pages, the skill-authoring page.
Seed: the user — the loopy-debug skill "starts with 'to reproduce these bug
reports'… Anthropic recommends defining the task first… task definition and
project background, followed by the mindset, the methodology"
(`5305d9d6/3c9d63c5`); then: no ten-part template, three layers as the
usual shape, teach the shaping from goals and constraints.

| friction | count | reading | verdict |
|---|---|---|---|
| skills open mid-stream — a mechanism, a trap, or a count of things in the anchor's seat | dotfiles ≈ 8 / 47, planlab ≈ 17 / 50; "Two/Three X" openers 10 across both | observed (static); the first version of pl-loopy-debug (08-10) also opened mid-stream, so the opener is an authoring prior, not a revision-pass cut | **instructions** — a `## The shape` section: three layers in reader order, formatting as the way layers show |
| the rulebook said structure in one clause and showed none | 1 clause in a 249-word paragraph; 0 uses of header/bullet/formatting; The bar 11 bullets averaging 80 words | observed | the bar regrouped under three sub-heads; surfaces under sub-heads; the shape carries an avoid/target pair from the corrected skill |
| the user compensates with a standing structure ask | 71 / 181 sessions (upper bound) | observed; same mechanism as "concise but informative" (first pass) | its vocabulary folded into the shape section |
| the lens had no name for the two shapes | — | observed | *hook before anchor* replaces *assumed conversational context*; *flat hierarchy* added |
| altitude rule had no account of when a fixed sequence is right | user: "you can still provide tutorials for step-by-step procedures" | design | the fragile-or-irreversible exception in **Right altitude**; the vendor pages' scaffolding removals (verification, re-check) added to the cut list |

Decided by the user: no ten-part template in the guide; three layers as
the usual shape, not a rule; a section in the rulebook, not a satellite
(first pass: satellites went unread).

Next pass should measure, after 2026-09-08: H2/H3 count and median
paragraph length of skills edited under the rulebook (target: layers
visible, bullets under ~60 words); the share of invoking prompts still
carrying the structure ask (target: falling); the opener of any skill
authored under the rulebook (target: layer one first); Edit-row delta
sign per window, as before. Quality condition for reversal: revision
passes that add headers without shortening, or skills whose first layer
grows past a paragraph.

Cold readers (two, fresh, read-only): authoring route — a new `dotadd-audit`
skill from a blank file; revision route — the pass over `write-email` and
`read-email`. Shared stalls, fixed: the surfaces section was itself a flat
hierarchy (now one bullet per rule under sub-heads); "steps only where
order matters" had three homes (layer two is the home; the altitude rule
points at it); "Never ask for the latter" was a no-op after "refusal class"
(deleted). Single-reader fixes: the output contract had three partial homes
(one clause in layer one); the pass was undefined when pointed at files
rather than a diff (now: every line is touched); the no-op cut in step 3
conflicted with the bar's run-it-to-know rule (a doubtful no-op is marked,
step 5's cold read settles it); *stale cache* added to the lens, and
*hook before anchor* covers a missing first layer; the sibling-skill
pointer said what to copy (frontmatter and header order, not method); the
Fable guide is named where it is echoed; frontmatter's two house exceptions
are labelled as exceptions. Not applied: a done-line after every section
(the completion rule was narrowed instead to instructions the reader
executes).

Length: 2579 → 3050 words (`wc -w`, whole file). The named gap is the
shape section with its example pair (≈ 450 words); the rest of the file is
net flat after trimming every bar bullet. Deliberate keeps: the two Fable
policies under Instructions (user decision, first pass); the step-3
transform example; "never" in the composer rule and in "never the dump".

Goal review (codex, cold, `~/.local/state/envoy/jobs/dotfiles-4f711dad/20260908-120646-review`,
2 min): achieved at the document level, no design objection, runtime
unproven. Findings, all confirmed and fixed in the follow-up commit: the
shape's task-first opening and the surfaces' data-first rule conflicted
with no precedence, and the data-first rule had dropped the vendor page's
large-input scope (now: a prompt built around large source material opens
on the task, material next, question last; the shape points there);
"refusal class on current models" overstated the Fable 5 page's "can
trigger" (qualified); the step/heuristic/reference labels were a second
classification beside the layers (labels cut, the instruction kept); the
lens was itself a flat hierarchy with remedies restating the bar (now a
list, remedies only where the bar does not carry them). Departures from
the vendor pages the reviewer judged earned: no fixed example count;
explicit formatting guidance; verification scaffolding removed per model
rather than wholesale.

## 2026-09-25 — the planlab house layer and `loopy-prompt-check`

Corpus: claude user turns naming `docs/loopy/prompting-guide.md` with a
review verb (`%eview and revise%`, `%self evaluation and improvement%`,
`%for prompt problems%`, `%review and revise based%`), excluding `#…`
briefs and dispatched `You are revising…`: 34 invocations / 26 sessions,
08-20 → 09-23. Guide writers: Edit/Write or Bash patch rows on the file,
40 sessions (some rows are reads caught by the Bash predicate). Production: 90 days of customer Loopy messages over
`planlab backstage db` (2,828 hand-typed, 16 workspaces; one customer
66 %), scratchpad `vocab/FINDINGS.md`. Web: GAO-16-89G, DCMA PAM 200.1,
AACE 10S-90, SCL protocol, UFGS 01 32 01, P6 help, NEC guidance.

| finding | evidence | verdict |
|---|---|---|
| passes apply the house mechanics, not the domain | ~30 reports: truth claims ~25, leaks ~12, cache ~12; planner-vocabulary-in findings 4, none drawn from the guide; domain text ≈1.5 % of 29 KB | instructions — register rebuilt from production + standards |
| the guide taught blind appends | its preamble and step 5 ("lands here with its evidence") overrode the doc standards' "never an append target"; pass writers 08-13 → 08-19, `pl-loopy-handoff` sync writers 08-26 → 09-24; 15.8 → 29 KB | user confirmed; admission rule in step 5, the sync admits and reports, the snippet reports only; this rulebook's pointer now says "a rule with a pointer to its record" |
| most of the guide restated this rulebook | calibration binds, the review pass, 8 binding conventions | cut; 29.0 → 17.9 KB with the domain layer added |
| the listed register was the author's, not the customer's | 4 of 7 listed terms rare; misread "slippage" (customer report), NEC terminal float, coined names; leaks 62 / 1k final replies are script, helper, mount, sandbox, JSON — the listed infra words 0.6 / 1k | new research note `docs/loopy/research/2026-09-25-planner-register-production-read.md` |

Cold readers (three, read-only): the revision pass on a seeded refusal and
skill paragraph (found every seeded defect; gaps fixed — bridge failures'
two readers, skill-test pins, regeneration commands, unit helper); the doc
sync on two reported lessons (rejected the general one, edited the owning
entry for the domain one; fixed — one admission test, a named admitter,
new-entry case); a new NEC skill (fixed — baseline vs Accepted Programme,
NEC terms and float sharing, read-or-ask for context-dependent terms,
reader-aware glossing, the in-repo NEC reference).

Next pass should measure, after this lands: guide size and the diff shape
of each later edit (target: edits into owning entries, no case narrative);
handoff closing reports naming admitted / rejected lessons; register
findings per `loopy-prompt-check` report (target: rising above 4 / 30);
Loopy's leak rate per 1,000 final replies (62 / 1k baseline, 30 days to
09-25) — a runtime outcome this pass did not test. Reversal condition: the
guide growing past ~20 KB again, or passes citing the register wrongly
(e.g. glossing NEC terms for a contract reader).

## 2026-09-28 — the reader's world, and judges

Seed: a jev prompt pass on the office mini (`b60cab46`, worktree
`feat/steward-jev-prompt-pass`, 09-27 → 09-28). The user opened it asking to
"think from first principles what the model receiving the prompts is
actually solving outside of our development terms", and closed it asking how
the rulebook helped. The user's reading: prompts should be written "in the
situation where the model is called, rather than from the developer's
understanding … a mock-up description, so long as it makes sense for the
model executing the job … probably not emphasized enough".

Corpus. Mini sessions are not in the laptop obelisk index, so their raw
JSONL was copied and read with `jq`: `b60cab46` with its consult voices
`a694a7d3`/`660c467b` (linked, not independent), and `ba19dcc8` (PR B,
`steward/recorded-judgments-closeout`, 09-26 → 09-27), which authored the
badge questions. 9 of the mini's 32 transcripts mention the rulebook path, so
every laptop count below undercounts. Laptop obelisk: user turns with
`source='claude'`, non-meta, non-sidechain, excluding `#…` briefs, `You
are…` dispatches and continuation summaries, since 09-08 13:00 UTC.

Usage since the second pass (laptop): 63 invocations / 41 sessions, all by
path, 16 sessions re-invoked. The main door is now the tabtype `prompt-check`
snippet ("Review and revise the model-facing surfaces this session
touched…"). Standing asks inside the invoking prompts: concise/short 5 / 63,
structure 3 / 63. Only 9 of the 63 windows have Edit-tool edits (7 longer, 2
shorter): with permissions bypassed most writes go through Bash, so the
edit-delta measure is too thin to read. Rule names cited in assistant text
(52 invoking sessions): one home 21, cold reader 20, plumbing 17, truth claim
12, no-op 11, negation 9, solve-in-code 0. The mini agent credited
solve-in-code with the largest effect without naming it, so name counts miss
paraphrase and are no cut signal.

| finding | evidence | verdict |
|---|---|---|
| the frame is the builder's system, not the reader's situation | PR B's `blocks_next` ("Does `reply` say the work cannot continue until the reader decides or provides something?") passed a review in which two cold voices were told to judge the jev prompts against this rulebook (`ba19dcc8`, review-r1 brief 09-27 09:18 UTC). It read the handovers the badge exists for (an optional decision left open while the next step runs) at 0.05–0.19, "right under its own definition" (`b60cab46` tool result 22:16). The replacement is a situation line plus "leave its reader something to decide or to provide … whether or not the work waits", with code adding the wait fact. On the same stored replies it scores seq 64 at 0.07 → 0.87 and seq 97 at 0.16 → 0.92 (spike, 23:00). Independent support: `b60cab46`/`ba19dcc8`; laptop `2f010ad7` (09-21, "imagine yourself as the model executing the doc loop … based on [the rulebook]"); the 09-25 house pass ("the listed register was the author's, not the customer's") | **instructions**. Layer one names the situation as the reader meets it. New bar rule **The reader's world**: answerable from the input, split the decision so code joins what the input cannot show, a stylised frame allowed when it keeps the right answer, and an acting reader's frame omits but never invents. The badge pair is its example. **Give the reason** now separates the collaborator template from a consequence inside an executor's world. Revision step 1 carries the answerability test; the lens gains *builder's frame* |
| no guidance for closed-question judges | Astra's ablation over 60 real calls ($0.00445): "the stronger observed mechanism is treating 'no hold' as 'no prerequisite decision'" (`b60cab46` tool result 22:06). The wording had been tuned on one card's 18 replies; the pass labelled 122 real replies (held locally, since most carry a customer's text) plus 40 edited cases, with no held-out split recorded (corrected 09-28 against the spec `2026-09-28-judgments-with-their-evidence.md`; the first version of this line said 123 with a held-out half, a planned step written up as done), and the situation text is part of the question set's version digest (mini branch `8312867659`, `questions.ts`) | **instructions**: a short **Judges** surface section covering input as evidence, self-arguing text, and calibration by labels. `typesafe-ai` stays the vendor home. Single workstream: watch it |
| mini sessions invisible to the index | 9 / 32 mini transcripts touch the rulebook | no change here; the next pass reads the mini by hand |

The cause is attributed to the rulebook, not to the authors. The first-layer
words "the system it belongs to" and a developer-story reason example were
the mini agent's inference; no session shows an author quoting them. What the
record does show is that fragments of the rule already existed and did not
catch the badge. Revision step 1 translated author requests into the
reader's goal, the familiar-term test covered names, and solve-in-code's
*inform* covered missing facts, yet the reviewers applied mechanics: one
thing per question, leaks, and cuts. Deliberate keep: "never invents" is an
earned `never`, because a reader that acts on the real system turns an
invented fact into a wrong action.

Cold readers (two, fresh, read-only, scenarios with no hint of the change):
authoring route — a judge in front of a merge bot's auto-merge, the request
written in the builder's terms (`merge-block`, `queued/held/merged`, lockfile
diffs); revision route — the pass over a headless verify session's prompt
written in pipeline plumbing. Both applied the new rule unprompted. The judge
never saw the internal names or the bot's states, code joined what it knew,
the description's self-claims were marked not evidence, and trust waited on
a labelled replay with edited copies. The session prompt's "the drain
advances the task unless a hold row exists" became "code review starts when
your turn ends", with nothing invented and the grader cut. Fixed from their
reports: *give the reason*'s consequence conflicted with a judge's input (a
judge now gets no consequence of its verdict, stated once with its home in
Judges); oversized evidence (code cuts to what the criteria name, and a cut
that could hide the deciding part makes the verdict unsure); the `typesafe-ai`
pointer now says what it settles; two Judges bullets repeated the
situation-line point (merged); "the criteria are the whole instruction" now
names the question too; the pause policy assumed ending the turn waits (a
pipeline session is now told the host's way to pause), and its trigger
"across turns" now reads "over many steps or reports to someone who did not
watch"; the lens had no name for a missing reason, skip, done condition, or
output contract (*bare rule*). Not applied: an escape for truth claims whose
source is unreachable, which came from the read-only scenario and not from
real passes; tagging outputs by reader, which the re-ground policy, *bare
rule*, and solve-in-code already carry.

Length: 3192 → 3830 words (`wc -w`). The named gaps are the reader's world
with its example pair (both readers called the pair the most useful text for
their task), Judges, the pipeline pause clause, and two lens entries. Neither
reader found a no-op, so nothing was cut.

Decided by the user, same day: the Judges section leaves the main body,
because most sessions never write for a classifier-style model. Material
of that kind goes into a case-study folder beside this file: one domain pass
per file, read only by sessions working in that domain (Jev first). The mini
session writes the first case study from its own pass. The removed section
(in `93e11fa`, with its cold-reader fixes) is starting material. Its general
half stays in the body: the reader's world, answerability, and code joining
what the input cannot show. The judge-specific sentence in *give the reason*
went with the section. The main body is now 3592 words.

The first case study landed the same day as
`case-studies/jev-steward-judgments.md` (1854 words), written by the mini
session. Checked against branch `37d41c0e38`: its file paths, the bands
(badge 0.6 / 0.3, residue 0.25 / 0.2), the 32k cap, the `hostWaits` join, and
the counts (76 asking: 47 / 23 / 6; 46 non-asking, none yes; 34 residue
files). One heading changed from "What changed, layer by layer" to "What
changed", so it does not collide with the rulebook's layers. The mini
session's proofread also moved the body's *reader's world* example from the
badge pair (now in the case study) to an agent prompt, since most readers of
the body write for agents, and added the pointer under Pointers.

Next pass should measure, after 2026-09-28, on both machines: whether prompt
passes over questions for a model (judges, gates, graders) name the
*builder's frame* or answerability, and whether their questions ask what
the input shows (target: every judge question passes the answerability test
as written); whether sessions in a case study's domain read it (the pointer's
hit rate), and whether the rest leave it unread. Reversal condition: a
stylised frame that changed an acting agent's behaviour on the real system,
passes that invent situation text for agents that act, or case studies
turning into a second rulebook that restates the body.

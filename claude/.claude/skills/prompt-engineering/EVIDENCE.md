# prompt-engineering — evidence log

One entry per mining pass over the sessions that read or invoked this
rulebook; counts are written so the next pass can re-run them. Passes run
under `improve-tool`; queries are obelisk scripts over `tool_calls` reads of
the file and user turns naming it.

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

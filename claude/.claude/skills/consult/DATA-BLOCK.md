# The data behind a position — the block a brief carries when numbers do

Reached from `consult/SKILL.md` step 2 and `review/SKILL.md` step 2. One
home for the rule; each brief template carries the section's slot and the
output item that consumes it.

## When it fires

The position, the cause or the change under review rests on a count, a
rate, a timing or any measurement this session produced: a production
database query, a log-analytics run, a query over session history, a
project's own evidence command, an eval or benchmark, a hand classification
of rows. A number measured by someone else is a premise, checked at its
source like any other, and does not fire it. With nothing session-produced
in the brief, the section and the output item are deleted.

The method goes on trial before the conclusion because the defects that
decide a round sit upstream of every conclusion — a sweep over the whole
session where the instruction governs a window, a predicate that measures
the reviewer's vocabulary, one rater's soft boundary, the wrong denominator,
a receipt that reads differently at its source — and a voice that starts
from the conclusion critiques the numbers inside its frame.

## The section

Observed register only: what was pulled, how, what came back. Every
conclusion drawn from it stays in the position, where the voice attacks it.
In a review brief it is the template's own section ("The data behind this
change"); in a consult brief the bullets go inside "What we observe" without
a heading of their own.

<example>
- **Source and window:** the Obelisk session index (`~/.obelisk/obelisk.sqlite`), Claude sessions only, 2026-09-01 → 09-22.
- **Population and denominator:** one row is a pickup window — a user turn carrying `Pickup gate:` and `Brief:` up to the next non-meta user turn; 78 windows, 42 with a design packet. Excluded: this session, continuation summaries, sidechains, 7 Codex pickups.
- **Predicates and queries:** `<scratchpad>/consult/last-query.mjs` and its outputs `pickups.json`, `design.json`, `consult.json`; the packet is the last assistant text in the window matching `## 5|ountershape|Framing:`. The voice holds `obelisk --query` and can re-run or vary any of them.
- **Classification:** section 5 of each packet read by one rater into proposal / hybrid / countershape; the hybrid-versus-countershape boundary was a judgment call.
- **Coverage gaps:** stored text truncates at 10,000 chars, so four packets lost their tail; a packet that omitted the section heading is unmatched.
- **Not measured:** consult adoption matched packet → dispatched position → synthesis; the "no foundational objection" count is the voice's own phrase over the whole session.
- **Receipts:** `21cde994` (split sent back), `e10cb080` `9dd07e2f` (a consult replaced the shape), `5cda2689` `f3315735`.
</example>

## The output item the voice fills first

Item 0 in a consult and a full review; in a goal review, the item after
the expectations written blind.

```markdown
0. **The method** — before any conclusion: is the right data pulled for the
   question, is data missing that would change the answer, is the approach
   sound, and which counts or claims it cannot support as stated. Doubt a
   count: re-run or vary it if the brief says you can, else say what you
   would run and what a different result would change. "Sound, with these
   limits" is a real answer.
```

<example>
0. **The method.** The step-back sweep ran over every project turn; inside the packet windows the instruction governs, the count is 2 of 36, not 8 (re-run: the same predicate joined to the window table). What it supports is a standing preference, not a packet failure. The overturn predicate matched to the session's end and truncated at 300 chars; `e10cb080` is a replacement it missed. The 42-packet classification is sound with one limit: the five "countershape wins" that are sequencing changes belong in their own bucket.
</example>

## Before dispatch

- Save every query and its raw output beside the brief; cite by path. A
  result that exists only as tool output is re-run into a file — displayed
  output is truncated, and a transcription is not raw. A measurement that
  cannot be repeated (a process since gone, a one-off sample) is saved
  verbatim, labelled with when and how it was taken.
- State what the voice can run: the command and credential it holds, or
  that it judges from the saved queries and outputs alone.
- Confirm the sweep ran over the window the instruction governs, not the
  whole session or project.
- Name the rater and the soft boundary, so the voice can re-read three rows
  and disagree.

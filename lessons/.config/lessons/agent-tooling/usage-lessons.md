# Usage lessons — writing the instruction layer of an agent-facing tool

A tool whose user is an agent has an **engine** (the code that does the work)
and an **instruction layer** (the skill, doc, `-h`, or snippet that says how
to drive it). Session history is the only honest account of where the pair
costs its user. These are the lessons that survived several mining passes
over that history; the passes themselves are the provenance below.

## The bar

- **Teach patterns, in two classes only.** The hot path nearly every
  session follows, and the rare case that matters and is hard to discover
  on one's own. Everything else is reference behind a pointer or cut.
- **Examples over prose; prose where prose is due.** A worked command with
  its output shape teaches what a paragraph describes; a **trap table**
  (the field an agent guesses → the field that exists) beats a paragraph
  of "look it up, don't guess". Text carries what no example can — the
  why, the trigger and its skip condition, the judgment call. The section
  below says what makes an example worth its lines.
- **Show the high-leverage pattern, not every case.** A few examples that
  carry the gist teach a reader to write the one they need; a covering set
  teaches them to search for a match and stall when none fits. Say so in
  the text — "patterns, not coverage" — so the reader knows inventing is
  expected. Both first improve-tool runs invented their deciding facet
  from MINE.md's shapes; that is the mechanism working, not a gap.
- **A stated rule that agents still break is not fixed by restating it.**
  The model's prior beat the prose once and will again. Move the answer
  to where the prior cannot act: the engine accepts the input the agent
  holds, the error prints the nearest match, the output ships a digest —
  or a worked example shows the right shape.
- **Behavior is not intent.** A pattern that recurs in the history is
  either a workaround the user tolerates or the thing they have been
  fighting, and the index cannot tell which. Interview before promoting;
  a correction the user typed outranks any count.
- **Smallest edit per signal, after the first pass.** A rewrite is for
  instructions that predate their engine; every later change is the
  smallest edit that captures one signal, named in the commit.
- **Measure the doctrine gap before writing doctrine.** Count the door the
  instructions present against the door agents take (calls / distinct
  sessions). What agents rebuild by hand in every session — a join, a
  loop over an output file, a poll — is the command that does not exist
  yet.
- **The facets follow the engine's output kind.** Consumed output (a CLI)
  is measured by drive cost — subcommands, errors, re-rolls, workarounds.
  Findings (lint, audit, tests, review) are measured downstream: what the
  repair changed — a class repaired by ±1-line bookkeeping measures the
  world, not the tool (wiki lint: 229 of ~265 flags, `c37919b5`). A
  document is measured by what came after it was read — pointer hit-rate,
  and the Explore prompts spawned inside its window (`1780f1fe`). On the
  wrong facet set every count collapses to "N calls, no flags".
- **The request is the first interview.** Read it for verdicts before
  asking, and when the user is not live write each open verdict as
  `assumed:`, build, and put the assumptions first in the recap — a
  blocking interview in an autonomous session stalls the whole pass
  (`1780f1fe`), while a live one settles the ledger in a turn (`c37919b5`).
- **Read the top failure class against the engine's code before calling
  it discipline.** More than once the dominant error was an engine branch
  that dropped its own helpful message.
- **Instructions describe an installed engine.** Engine change, tests,
  version bump, install, `-h` verified — then the prose. A line that
  describes a behaviour the binary on the machine lacks is a trap of the
  instructions' own making.
- **Verify with a cold reader per route.** An agent with nothing in
  context but the files, a concrete scenario, and no credentials reports
  the first line where it would guess a flag, path, field, or file. Two
  readers stalling at one line is the first fix; a cut one reader proposes
  that another's sequence relied on is not a cut.
- **Leave `allowed-tools` out of a skill.** This machine runs Claude Code
  with permissions bypassed as the standing mode, so an allowlist buys no
  safety; it only narrows what the skill can do, invisibly until a run hits
  the wall. The subtler cost is below.
- **Every rule traces to evidence.** A rule that traces to neither a
  measured friction nor a rulebook principle is sprawl; the engine's
  evidence log keeps the receipts so the next pass can re-check whether
  the fix held.

## Examples over prose, and where prose is due

A model imitates what it is shown more strongly than it follows what it is
told, so an example is the higher-bandwidth instruction — and the one whose
quality is checkable. The instruction layer of a good tool reads like a
worked session, with text between the blocks only where a block cannot
carry the point.

An example earns its lines when it is:

- **Real** — a command that runs as written against the engine that is
  installed, with values an agent would actually hold (a subdomain, a
  file path it just produced), not `<placeholder>` where a real value
  fits; placeholders only where the value is genuinely the caller's.
- **Complete for one pattern** — the whole hot path in one block (the
  dispatch *and* the collect, the query *and* how the result is read),
  since an agent copies the block and runs it, and a block that stops
  halfway is where the guessing starts.
- **Showing the output shape** — the two lines of what comes back that
  the next step reads, or the error the agent will meet and what it
  means. Output is what the agent has to interpret; a command without
  its output teaches half the pattern.
- **Annotated at the decision points** — a short trailing comment where
  a value must be chosen and the rule for choosing it, nowhere else.

Prose is due for what an example cannot show: the **why** (a reason
generalizes to cases the example did not cover), the **trigger and skip
condition** of a pattern (when this path, when not), the **judgment**
left to the agent, and the one-line **identity** of what a block is for.
Prose that re-describes the block beneath it is a no-op; prose that
explains a mechanism the agent never touches is developer-facing. The
test for a sentence: cut it — does the example still teach the same
thing? Then it was decoration.

This rule appears as an explicit instruction in 13 user prompts across 7
sessions (2026-06-28 → 2026-08-29), always beside the rulebook pointer —
which is why it is written down here.

## Why the prior wins

An instruction is a probabilistic lever; a schema, a default, an error
message that carries the answer is not. When an agent guesses `id` on a
table whose key is `runId`, or types the human-readable name where the
command wants an internal id, the guess is the model's pretrained prior
for how such things are usually named. Prose competes with that prior on
every turn and loses a measurable share. The engine does not compete: it
accepts the guess as an alias, or rejects it with the right name in the
error, and the friction is gone from every future session. The
instruction layer's job is then the part code cannot carry — which
command answers which question, and the rare path nobody would find.

## What the doctrine gap looks like

The instructions of one toolkit presented a staged evidence command as the
front door and raw SQL as the escape hatch; the sessions ran raw SQL ten
times as often. Agents were not ignoring the doctrine — the staged command
did not answer the questions they had, so they answered them by hand, the
same joins and the same loops session after session. The count was the
finding, and the commands agents kept hand-writing were the spec for what
to build.

## A rule that needs an allowlist is not carrying its weight

A workflow rule shaped so an allowlist can enforce it inherits the
allowlist's arbitrary edges, and those edges then read as design. The
obelisk skill spent months routing every query through the Write tool to
stay inside `Bash(obelisk:*)`, banning the heredoc that would have done the
same job in one call instead of two — a rule that looked earned, measured,
and evidence-backed, and was buying a benefit that did not exist. When a
rule's only justification is the allowlist, delete the rule with the
allowlist.

## Feedback compounds only if it is captured and re-read

Feedback to an agent normally dies with the session. Here it does not — the
session index keeps every correction the user typed, at no extra cost to
them — but a correction is only as findable as its wording, and a keyword
sweep for "wrong" or "again" drowns in briefs and snippets. A one-word
marker (`friction:`) in the correction makes it mined verbatim. The other
half of compounding is re-measurement: a pass that records each friction's
count beside its fix lets the next pass ask whether the fix held, which is
the only evidence a rule has earned its place.

## Observed, not inferred

A stall in a job log is a fact; "the engine hung" is an inference. One
mining pass read a cluster of stalls as engine failures until the user
pointed out the laptop had left wifi on a commute. A ledger records what
the logs show and what it cost, and lets the tag (engine or instructions)
follow only from that.

> _Lesson · distilled 2026-08-29 from the envoy CLI pass (`d1a2fe7d`), the
> planlab triage-toolkit passes (`54711f30`, `e96abdd5`), the
> handoff-sweep pass (`b5f5e59f`), and the obelisk skill's own
> LESSONS.md. Applied by the `improve-tool` skill._

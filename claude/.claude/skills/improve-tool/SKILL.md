---
name: improve-tool
description: Improve an agent-facing tool (skill, CLI, script, snippet, doc) from the sessions that used it.
disable-model-invocation: true
argument-hint: <the tool: a skill path, CLI, doc, or snippet> [its engine] [a seed session, worktree, or complaint]
---

# Improve a tool from its usage

An **agent-facing tool** has two layers: the **engine** — the CLI, scripts, or
code that does the work — and the **instructions** — the skill body, doc, or
snippet that tells an agent how to drive it. A pure-instruction tool's engine
is the repo's mechanisms (hooks, Makefile targets, ignore files, tests); a bare
CLI's instructions are its `-h` and its errors. Past sessions record where the
tool made agents work harder than the problem required; every fix lands on one
layer or the other, and only the user can say which patterns were wanted.

Reading: [`../obelisk/SKILL.md`](../obelisk/SKILL.md) before the first query;
[`MINE.md`](MINE.md) for the usage-analysis script; [`COLD-READER.md`](COLD-READER.md)
for the verification prompt; `~/.config/lessons/agent-tooling/usage-lessons.md`
for what past passes established about writing the instruction layer, with
the receipts behind every rule below.

## Process

1. **Map the surface.** Read the instructions and every satellite they
   point at. Name the engine and where it lives — often another repo — and
   compare the installed engine with its HEAD; instructions written against
   an uninstalled engine are a finding on their own. Write the **search
   signatures** into the ledger header:

   | to find | signature |
   |---|---|
   | invocations | `messages.skill`, `/<name>` in user text, and the tool's **absolute path** in user text — skills here are invoked by path as often as by slash |
   | engine calls | `tool_calls.name='Bash' AND input_json LIKE '%<cli> %'`; the engine's state dirs and output files |
   | the seed | the session, worktree, or complaint the user named |

   Done when the engine, its install state, and the signatures are written.

2. **Mine.** First the previous pass: the engine's evidence log names the
   frictions it fixed and their counts — re-measure those, since a fix that
   did not hold tops the new ledger. Then one batched obelisk script per
   round from [`MINE.md`](MINE.md), in the variant for the engine's output
   kind — consumed output, findings, or a document — whose facets are fixed:

   - **usage shape** — calls and distinct sessions per subcommand and flag.
     This ranks everything after it, and it measures the **doctrine gap**:
     the door the instructions present against the door agents take.
   - **failures** — error classes with counts; the same command re-run
     verbatim; reads of engine output that hit the 10 k truncation.
   - **workarounds** — ad-hoc `python`/`jq`/`sleep` loops over engine
     output, each with the assistant text just before it: the question the
     agent was answering by hand is the command that does not exist yet.
   - **user voice** — the user's corrections in sessions that used the tool,
     `friction:` markers first. This facet outranks every count: a
     correction states intent, an error only states cost.
   - **the seed**, expanded vertically with `thread()` / `context()`.

   When an output's shape is in question, run a **live trial** of the
   engine's read commands into the scratchpad and measure what the agent
   sees — a dump's size is not in the index. Done when every facet has a
   count or a measured empty, written as `calls / distinct sessions`.

3. **Write the friction ledger** — `<scratchpad>/<tool>-frictions.md`: the
   usage-shape table, then frictions ranked by measured cost. Each carries
   its count, session-id receipts, what the instructions already say about
   it, a **reading** of what the pattern means marked *observed* or
   *inferred*, and candidate fixes tagged **engine** or **instructions**.
   Two rules decide the tag:

   - A rule the instructions already state and agents still break is not
     fixed by restating it — the model's prior beat the prose once and will
     again. Move the answer into the engine (accept the input the agent
     holds, print the nearest match in the error, ship a digest instead of
     a dump, add the check a red line lacks) or into a worked example.
   - The top failure class is read against the engine's code before it is
     called a discipline failure; a dominant error is as often an engine
     branch dropping its own helpful message.

   Done when each of the top three frictions answers "how many, and where"
   with a number and ids, and every reading says which of the two it is.

4. **Interview the user on the ledger.** The index records what agents
   did; only the user knows what they wanted, and a recurring pattern is as
   likely the thing they have been fighting as the thing to promote. The
   request is the first interview: read it for verdicts before asking —
   "packing too many route details" already judges a friction. For each
   top friction it leaves open ask **pattern or anti-pattern** — promote it
   into the engine, or fix the cause so it stops; for a doctrine gap,
   change the doctrine or enforce it. Then the two questions the ledger
   cannot raise: what they *avoid* doing with this tool today, and where
   they want it to go — a vision reorders the ledger more than any count.
   Put every *inferred* reading to them as a question, and name what stays
   uncertain after the answers.

   The user is often not live. Then each open verdict is written into the
   ledger as `assumed: <verdict>, reversible`, the build proceeds, and the
   recap lists the assumed verdicts first so one reply flips them. The one
   real stop is a verdict that changes what is built rather than how it is
   worded — an engine contract change, deleting something with external
   consumers; for those, and whenever a fix changes the engine's contract,
   run `/consult` in approach mode with the ledger as the position. Done
   when each top friction carries a verdict — the user's, or an assumed one
   marked as such in the ledger.

5. **Build engine first, instructions second.** Instructions describe
   engine behaviour, so they are written only against an installed engine:
   change → tests → version bump → install → verify `-h` → then the
   instructions. When the engine repo is the user's side, write its
   handoff with `/handoff` and stop at the boundary; the instruction round
   starts when they report it shipped. Done when every engine item is
   landed or handed off.

6. **Change the instructions** under
   [`../writing-for-agents/SKILL.md`](../writing-for-agents/SKILL.md),
   [`../prompt-engineering/SKILL.md`](../prompt-engineering/SKILL.md), and
   the usage lessons as the tool-specific lens — in one line: teach the hot
   path and the rare hard-to-discover case, each as a real code example
   with its output shape, prose only where prose is due. A full rewrite is
   for a first pass, or instructions that predate their engine; every later
   pass makes the **smallest edit that captures each signal**, and the
   commit names the signal, so the next reader can judge the change against
   its evidence. Done when every change traces to a ledger line or a
   rulebook rule and has been run through the prompt-engineering defect
   list as the exit check.

7. **Verify with cold readers, then review.** One background agent per
   route through the instructions, from [`COLD-READER.md`](COLD-READER.md):
   the files from disk and nothing else in context, a concrete scenario, no
   engine calls, a ranked report. Fix what they stall on and re-read after
   the fix. Then `/review full` on the commits. Done when a cold reader runs
   the scenario without guessing a flag, path, field, or file.

8. **Record and report.** Append a dated entry to the engine's evidence log
   (`EVIDENCE.md` or `LESSONS.md`, whichever the repo keeps; start one only
   when none exists): one mining pass per entry — date, corpus size, each
   friction's count and verdict, the lesson that survived — written so the
   next pass can re-run the count. Offer the obelisk memory. Report the
   usage shape, the frictions by rank with what landed on which layer, what
   was handed off, and the receipts.

## Altitude

The ledger drifts toward a session report. The numbers a decision rests on
sit beside the decision; per-session detail stays in the index. Three
frictions with counts beat an inventory of everything that ever went wrong.

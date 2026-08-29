---
name: improve-tool
description: Improve an agent-facing tool — a skill, CLI, script, snippet, or doc — from the sessions that used it: mine the history for measured frictions, fix each at the engine or the instructions, verify with cold readers.
disable-model-invocation: true
argument-hint: <the tool: a skill path, CLI, doc, or snippet> [its engine] [a seed session, worktree, or complaint]
---

# Improve a tool from its usage

An **agent-facing tool** has two layers: the **engine** — the CLI, scripts, or
code that does the work — and the **instructions** — the skill body, doc, or
snippet that tells an agent how to drive it. A pure-instruction tool has an
empty engine; a bare CLI has instructions in its `-h` and errors. Past
sessions are the record of where the tool made agents work harder than the
problem required, and every fix lands on one layer or the other.

Reading: [`../obelisk/SKILL.md`](../obelisk/SKILL.md) before the first query;
[`MINE.md`](MINE.md) for the usage-analysis script; [`COLD-READER.md`](COLD-READER.md)
for the verification prompt; `~/.config/lessons/agent-tooling/usage-lessons.md`
for what past passes established about writing the instruction layer.

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

2. **Mine.** One batched obelisk script per round from [`MINE.md`](MINE.md).
   Its facets are fixed because every past pass converged on them:

   - **usage shape** — calls and distinct sessions per subcommand and flag.
     This ranks everything after it, and it measures the **doctrine gap**:
     the door the instructions present against the door agents take.
   - **failures** — error classes with counts; the same command re-run
     verbatim; reads of engine output that hit the 10 k truncation.
   - **workarounds** — ad-hoc `python`/`jq`/`sleep` loops over engine
     output, each with the assistant text just before it: the question the
     agent was answering by hand is the command that does not exist yet.
   - **user voice** — the user's corrections in sessions that used the tool.
   - **the seed**, expanded vertically with `thread()` / `context()`.

   When an output's shape is in question, run a **live trial** of the
   engine's read commands into the scratchpad and measure what the agent
   sees — a dump's size is not in the index. Done when every facet has a
   count or a measured empty, written as `calls / distinct sessions`.

3. **Write the friction ledger** — `<scratchpad>/<tool>-frictions.md`: the
   usage-shape table, then frictions ranked by measured cost, each with
   its count, session-id receipts, what the instructions already say about
   it, and candidate fixes tagged **engine** or **instructions**. Two rules
   decide the tag:

   - A rule the instructions already state and agents still break is not
     fixed by restating it. The model's prior beat the prose once and will
     again: move the answer into the engine (accept the input the agent
     holds, print the nearest match in the error, ship a digest instead of
     a dump) or into a worked example.
   - The top failure class is read against the engine's code before it is
     called a discipline failure. Past passes found the dominant error was
     an engine branch that dropped its own helpful message.

   A document's engine is the repo's mechanisms — hooks, Makefile targets,
   ignore files, tests, the composer that renders it — so the first rule
   applies there too: a red line a session once crossed wants a check, and
   the prose keeps only the why.

   Keep **observed** apart from **inferred** — a stall in a log may be the
   user's laptop leaving wifi. Done when each of the top three frictions
   answers "how many, and where" with a number and ids.

4. **Put the ledger on trial.** Present it; the user's answers fold in — a
   stall that was not a failure, a pattern they want promoted. When a fix
   changes the engine's contract, run `/consult` in approach mode with the
   ledger as the position: past rounds reversed a "missing commands"
   reading into a seam fix. Done when the user says build.

5. **Build engine first, instructions second.** Instructions describe
   engine behaviour, so they are written only against an installed engine:
   change → tests → version bump → install → verify `-h` → then the
   instructions. When the engine repo is the user's side, write its
   handoff with `/handoff` and stop at the boundary; the instruction round
   starts when they report it shipped. Done when every engine item is
   landed or handed off.

6. **Rewrite the instructions** under
   [`../writing-for-agents/SKILL.md`](../writing-for-agents/SKILL.md) and
   [`../prompt-engineering/SKILL.md`](../prompt-engineering/SKILL.md), with
   the usage lessons above as the tool-specific lens. The gist: teach
   **patterns** — the hot path nearly every session follows and the rare
   case that matters and is hard to discover — each as a real, complete
   code example with its output shape, and prose only where prose is due
   (the why, the trigger and skip condition, the judgment); a trap table
   beats a paragraph of "look it up"; every rule traces to a ledger line or a rulebook rule, and what
   traces to neither is on the cut list. Done when the rewrite has been run
   through the prompt-engineering defect list as its exit check.

7. **Verify with cold readers, then review.** One background agent per
   route through the instructions, from [`COLD-READER.md`](COLD-READER.md):
   nothing in context but the files, a concrete scenario, no engine calls,
   a ranked report. Fix what they stall on and re-read after the fix. Then
   `/review full` on the commits. Done when a cold reader runs the scenario
   without guessing a flag, path, field, or file.

8. **Record and report.** Append a dated entry to the engine's evidence log
   (`EVIDENCE.md` or `LESSONS.md`, whichever the repo keeps; start one
   only when none exists): one mining pass per entry, a few lines with
   session-id receipts and the lesson that survived. Offer the obelisk
   memory. Report the usage shape, the frictions by rank with what landed
   on which layer, what was handed off, and the receipts.

## Altitude

The ledger drifts toward a session report. The numbers a decision rests on
sit beside the decision; per-session detail stays in the index. Three
frictions with counts beat an inventory of everything that ever went wrong.

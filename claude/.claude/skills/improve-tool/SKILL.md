---
name: improve-tool
description: Improve an agent-facing tool (skill, CLI, script, snippet, doc) from the sessions that used it.
disable-model-invocation: true
argument-hint: <the tool: a skill path, CLI, doc, or snippet> [its engine] [a seed session, worktree, or complaint]
---

# Improve a tool from its usage

You are improving an agent-facing tool — a skill, CLI, script, snippet, or
doc — from the record of the sessions that used it, so the next agent pays
less to get the same work done.

An **agent-facing tool** has two layers: the **engine** — the CLI, scripts, or
code that does the work — and the **instructions** — the skill body, doc, or
snippet that tells an agent how to drive it. A pure-instruction tool's engine
is the repo's mechanisms (hooks, Makefile targets, ignore files, tests); a bare
CLI's instructions are its `-h` and its errors. Every fix lands on one layer
or the other.

Reading: [`../obelisk/SKILL.md`](../obelisk/SKILL.md) — the session index —
before the first query; the engine's evidence log (`EVIDENCE.md` beside the
instructions, or the repo's `LESSONS.md`) for the previous pass;
[`MINE.md`](MINE.md) for the usage-analysis script; [`COLD-READER.md`](COLD-READER.md)
for the verification prompt; `~/.config/lessons/agent-tooling/usage-lessons.md`
for what past passes established about writing the instruction layer, with
the receipts behind every rule below.

## Process

1. **Map the surface.** Read the instructions and every satellite they
   point at. Name the engine and where it lives — often another repo — and
   check it is installed at its HEAD: the binary the instructions name is
   newer than the engine's last commit (`ls -l` against
   `git log -1 --format=%ci`; an engine with no version flag has its mtime
   as the version). Instructions written against an uninstalled engine are
   a finding on their own. Write the **search signatures** into the ledger
   header — copied from the previous pass's evidence entry when one exists:

   | to find | signature |
   |---|---|
   | invocations | `messages.skill`, `/<name>` in user text, and the tool's **absolute path** in user text — skills here are invoked by path as often as by slash |
   | engine calls | `tool_calls.name='Bash' AND input_json LIKE '%<cli> %'`; the engine's state dirs and output files |
   | the seed | the session, worktree, or complaint the user named; none named → the latest invocation |

   Done when the engine, its install state, and the signatures are written.

2. **Mine.** First the previous pass: the engine's evidence log names the
   frictions it fixed and their counts — re-measure those, since a fix that
   did not hold tops the new ledger. When that log's last entry already
   carries the seed, this pass is a re-measure: `since` is the entry's date,
   the ledger opens with the post-fix count, and a window with no sessions
   yet is a measured empty, reported as such. Then one batched obelisk
   script per round from [`MINE.md`](MINE.md), in the variant for the
   engine's output kind — consumed output, findings, a document, or no
   engine (a pure-instruction skill: the files its sessions touched are the
   failure facet, and a rarely-invoked tool's population is the sessions
   that did its job without it). The facets:

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
   - **what came next** — the user's first turn after each engine call or
     invocation, read by position: a two-minute "go ahead" after every
     report is a stop that changed nothing; a long turn is the correction,
     and it rarely names the tool.
   - **the seed**, expanded vertically with `thread()` / `context()`.

   When an output's shape is in question, run a **live trial** of the
   engine's read commands into the scratchpad and measure what the agent
   sees — a dump's size is not in the index. Done when every facet has a
   count or a measured empty, written as `calls / distinct sessions`.

3. **Write the friction ledger** — `<scratchpad>/<tool>-frictions.md`: the
   usage-shape table, then frictions ranked by measured cost. Each carries
   its count, session-id receipts, what the instructions already say about
   it, a **reading** of what the pattern means marked *observed* or
   *inferred*, and candidate fixes, each tagged with its layer —
   **engine** or **instructions** — and its shape — `wording`, or `shape`
   when it creates or deletes a surface with consumers
   (`grep -rn 'skills/<name>' tabtype/ docs/ claude/` finds them) or changes
   an engine contract. The layer follows the usage lessons: a rule agents
   still break moves into the engine or a worked example, and the top
   failure class is read against the engine's code before it is called
   discipline. Done when each of the top three frictions answers "how many,
   and where" with a number and ids, and every reading says which of the
   two it is — three frictions with counts, per-session detail left in the
   index.

4. **Interview the user on the ledger.** Behaviour is not intent. The
   request and the mined corrections are the first interview: read both
   for verdicts before asking — "packing too many route details" already
   judges a friction, and a candidate fix a past correction already rejects
   is not open: mark it `rejected: <uuid>` in the ledger, neither build nor
   consult it, and recap it as considered. For each top friction still open
   ask **pattern or anti-pattern** — promote it into the engine, or fix the
   cause so it stops; for a doctrine gap, change the doctrine or enforce
   it. Then the two questions the ledger cannot raise: what they *avoid*
   doing with this tool today, and where they want it to go — a vision
   reorders the ledger more than any count. Put every *inferred* reading to
   them as a question, and name what stays uncertain after the answers.

   **Live** — the user has replied in this session: put the open verdicts
   to them and wait. When they name a window ("here for an hour"), spend it
   on the `shape` designs and the *inferred* readings; `wording` verdicts
   can wait.

   **Not live** — each open `wording` verdict is written into the ledger as
   `assumed: <verdict>, reversible`, the build proceeds, and the recap
   marks those rows so one reply flips them. A `shape` fix is never
   assumed: nothing of it is built. Its design — what is created, deleted,
   or changed, and why — goes to `/consult` in approach mode with the
   ledger as the position and the search signatures plus
   [`MINE.md`](MINE.md) in the brief, so the consultant re-mines instead of
   taking the ledger on faith; the recap leads with that design and the
   consult's verdict as the one decision waiting on the user. Done when
   each top friction carries a verdict — the user's, an assumed one marked
   as such, or `rejected` — and no `shape` fix rests on an assumption.

5. **Build engine first, instructions second.** Instructions describe
   engine behaviour, so they are written only against an installed engine:
   change → tests → install (a version bump where the engine has one) →
   verify `-h` → then the instructions. When the engine repo is the user's side, write its
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
   its evidence. Signal edits accrete, so the step ends with the
   **holistic pass**: every touched file read once more as one whole
   against both rulebooks — concise but informative, the hot path visible,
   no line that only makes sense beside the signal that added it — as its
   own commit. Done when every change traces to a ledger line or a
   rulebook rule, and every touched file has had its holistic read.

7. **Verify with cold readers, then review.** One background agent per
   route through the instructions, from [`COLD-READER.md`](COLD-READER.md):
   the files from disk and nothing else in context, a concrete scenario, no
   engine calls, a ranked report. Fix what they stall on and re-read after
   the fix. Then `/review goal` on the commits — did the surface land as
   one whole; a change of a few lines that two readers already cleared may
   skip it, said in the recap. Done when a cold reader runs the scenario
   without guessing a flag, path, field, or file.

8. **Record and report.** Append a dated entry to the engine's evidence log
   (`EVIDENCE.md` or `LESSONS.md`, whichever the repo keeps; start one only
   when none exists): one mining pass per entry — date, the corpus and the
   search signatures that selected it, each friction's count with the facet
   and constants that produced it (`F after_shape, cli='brief ', since
   2026-08-26`), its verdict and the layer it landed on, the lesson that
   survived, and the window the next pass should measure — a count without
   its predicate cannot be re-run, only approximated. Offer the obelisk
   memory. Report as one
   table — friction · count · verdict (the user's, or `assumed`) · what
   landed on which layer or was handed off — the usage shape above it and
   the receipts beside each row, so the whole pass reads from one message.

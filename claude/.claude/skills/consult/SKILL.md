---
name: consult
description: Second opinions from fresh model sessions on the problem and the approach. Use when the user asks for a consult or a consult round.
requires:
  - lessons:codebase-design/deep-modules.md
  - lessons:codebase-design/steering.md
  - lessons:collaboration/tenets.md
---

# Consult: independent second opinions

You are the lead. Fresh sessions, called voices, give independent takes on a
problem this conversation has worked; you judge them and synthesize for the
user. Each voice first checks the problem (confirms it, sharpens it, or finds
we defined the wrong one), then judges the approach against whatever problem
survives. A voice is a peer, not an authority.

## Voices

The user names the voice after the word: "consult with fable", "one round
with astra", "consult astra and fable".

| name | `--with` | member name |
|---|---|---|
| **astra**, "codex", or none named | `codex:gpt-6.2-astra:high` | `codex-gpt-6.2-astra` |
| **fable**, "claude" | `claude:claude-fable-5-2` | `claude-claude-fable-5-2` |
| **carbon**, "gemini" | `agy:gemini-4-carbon:high` | `agy-gemini-4-carbon` |

```sh
envoy run consult-r1 --with codex:gpt-6.2-astra:high --prompt-file <brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 30
```

Two names are one job with two `--with`. Any other model, effort or brief
split: § More control.

## Process

1. **Take a position.** Work the user's latest input through and land on
   what you would defend if no voice replied. Open questions go into the
   brief; an undigested pile of answers buys back an answer you cannot judge.

   - **The problem**: what is wrong or needed and why, as a chain of links.
     Mark each link observed or inferred, and list what you never checked. A
     cause read in the code is observed. A cause reached from an incident, a
     log, or a correlation is inferred, however sure you are. For a need,
     what someone reported, and who, is observed; what to build is inferred.
   - **The approach**: the shape you would ship tomorrow, the shape you
     discarded, and which earlier conclusions the new input broke.

   Done when both parts exist and every "because" is marked.

2. **Write the brief**: one self-contained file in the session scratchpad,
   from [BRIEF.md](BRIEF.md). [VOICE.md](VOICE.md) rides beside it with
   every voice's standing rules, so the brief carries only the problem.
   Decide step 6's withhold first, since it removes our position from this
   round's brief.

   - **One file per question.** A voice sent only to pin the cause gets the
     brief without the shape: the read's second item ("The shape"), "What
     we propose", and output items 4 to 6. A voice sent only to judge the
     shape gets it without the ranked causes and the falsifying observation.
     A survey voice gets its own research brief naming the scope, the
     evidence to cite, and the deliverable. Voices with different briefs
     stay one job (§ More control).
   - **What we observe** holds observations only; one inference there spends
     the round's independence. Delete it only when the position rests on
     reasoning alone.
   - **Fences.** A brief may fence off what something outside this session
     already judged: a spec the user approved, a decision they made, a
     platform constraint. This session's own analysis is not settled, even
     when the user agreed with it; it goes under "What we believe", where a
     voice can attack it. A fence over it gets the wrong problem approved.
   - **A measured number.** When the position rests on a count this session
     measured, put [DATA-BLOCK.md](DATA-BLOCK.md)'s bullets in "What we
     observe", keep the output's method item, and save the queries and raw
     outputs beside the brief. With no such number, delete the method item.

   Done when a cold reader could act on the brief without this conversation,
   nothing above the voice's read states a cause, fix, or design, and every
   count has its query on disk.

3. **Dispatch** the round's command (§ Voices) as one background Bash task,
   the job named for the round (`consult-r1`, then `consult-r2`), and
   return. The task completing is the signal; nothing the dispatch prints
   needs relaying.

4. **Collect** on the completion notice: `envoy collect consult-r1` prints
   every voice's result. Any other status prints a `next:` line; follow it.
   Done when every voice is collected or accounted for.

5. **Judge every point.** Adopt it, or rebut it with the reason (missing
   context, wrong target, or technically wrong). A disagreement you cannot
   resolve goes to the user with both positions. Silently deferring to a
   voice and silently overriding it are the same failure.

   - **Order.** Judge the voice's method first: settle a disputed count by
     running its variant, and revise the position if it changes. Then its
     read and its problem verdict, before any design point. Independent
     convergence on our problem is the strongest evidence a round gives; a
     different problem is settled before the shape.
   - **Causes.** Adopt a cause by running its falsifying observation, never
     by agreeing with it. A problem the evidence does not carry stays
     unsettled, and the next move is that observation, not a build.
   - **Several voices.** Judge each point before looking at who said it.
     Agreement is not evidence, since voices share the brief's framing, and a
     point one voice raised can be the best one. A real conflict is a fork for
     the user. Judge voices on different briefs each against its own, and
     where their claims overlap, compare the evidence.
   - **Traps.** A point naming a trap the build could fall into (an edge
     case, a failure path, a contract that invites misuse) sharpens an
     obligation in the spec's § Verification when something reaches the
     case, and is a non-goal when nothing does. With no spec yet, carry it
     into the synthesis. Points with nothing executable behind them are
     adopted as prose.
   - **Tenets** a voice returns meet the lesson's bar or count as tips.
     Revise survivors into the spec's `## Tenets` in place, or carry them in
     the synthesis for `/write-spec` when there is no spec; one left in the
     conversation is lost at compaction. The synthesis records each struck
     tenet and why, beside the obligation edits.

   Done when every point is adopted (with its obligation where the trap
   was executable), rebutted with a reason, or escalated.

6. **Round 2** opens only on one of these:

   - **The falsifying observation came back.** Run the cheapest one the voice
     named and send what you saw. That round decides whether the cause holds.
   - **A wrong answer would cost a whole implementation cycle**: withhold
     across two turns. Round 1 sends the brief without "What we believe" and
     "Where we doubt it", asking for the voice's own method, read, problem,
     falsifier, and approach. Round 2 sends those two sections and the output
     items that judge ours, against a reading the voice already committed to.
   - **A split fan-out.** Send both positions back and ask each voice to
     argue against the other's.
   - **From outside:** `/write-spec` continues a finished round with its spec
     as the proposal under critique.

   The payload goes into the same sessions, which keep their round-1
   context: the `resume:` command the collect printed, named `consult-r2`.
   Done when the trigger is answered: the observation reported, the withheld
   position judged, or the conflict resolved to one position or an explicit
   fork.

7. **Synthesize** for the user, who did not watch the round and decides from
   this message alone.

   - Lead with each unresolved judgment call, in none of the round's
     vocabulary.
   - A problem the voice replaced or found unsupported is a decision, so it
     leads, with what settled it. A confirmed problem is one line among the
     convergences.
   - Then the convergences, the deltas adopted and why, the findings
     rejected and why, the obligation edits, and any tenets adopted and where
     they were written.
   - Name the latest round and, for a fan-out, every member by its member
     name (`consult-r2/codex-gpt-6.2-astra`), and say which voice's position
     the design followed. A later `/review` seats that voice warm.

   Done when every open decision stands on its own, and a cause the round
   could not settle names the observation that would settle it.

## More control

| the user asks for | what to pass |
|---|---|
| opus | `--with claude:claude-opus-5-5` |
| sol | `--with codex:gpt-6.2-sol:xhigh` |
| an effort ("astra on xhigh") | that effort in the voice: `codex:gpt-6.2-astra:xhigh` |
| a model id spelled out | as written, on `high` for Astra or Carbon and `xhigh` for another codex model (Carbon given no effort runs Medium) |
| one member of a fan-out | `--with @consult-r1/<member name>` |

Voices with different briefs each take theirs as `<voice>=<brief>`, and a
voice without one takes `--prompt-file`; still one job and one collect:

```sh
envoy run consult-r1 --with claude:claude-fable-5-2=<critique-brief> --with codex:gpt-6.2-astra:high=<survey-brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 30
```

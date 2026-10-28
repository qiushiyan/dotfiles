---
name: consult
description: Second opinions from fresh codex or claude sessions on the problem and the approach. Use when the user asks for a consult or a consult round.
requires:
  - lessons:codebase-design/deep-modules.md
  - lessons:collaboration/tenets.md
---

# Consult: independent second opinions

You are the lead. Fresh sessions, called voices, give independent takes on a
problem this conversation has worked; you judge them and synthesize for the
user. Each voice first checks the problem (confirms it, sharpens it, or finds
we defined the wrong one), then judges the approach against whatever problem
survives. A voice is a peer, not an authority.

## Resolving the voice

Name the model on every cold voice, and the effort on a codex one, so the job
records what ran. Resolve it from the user's words:

```sh
--with codex:gpt-6-astra:high    # the default: no voice named, "codex", or "astra"
--with codex:gpt-6.1-sol:xhigh   # "sol"
--with claude:claude-opus-5-5    # "claude", "opus"
--with claude:claude-fable-5-1   # "fable"
--with codex:gpt-6-astra:xhigh   # another effort only when the user asks: "astra on xhigh"
```

A model id the user spells out goes through as written, a codex one on
`xhigh` unless they name an effort. A warm voice (`@<job>/<member>`) keeps the
model it started on.

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
   from [BRIEF.md](BRIEF.md). Decide step 6's withhold first, since it removes
   our position from this round's brief.

   - **One file per question.** A voice sent only to pin the cause gets the
     brief without the shape: the read's second item ("The shape"), "What
     we propose", and output items 4 to 6. A voice sent only to judge the
     shape gets it without the ranked causes and the falsifying observation.
     A survey voice gets its own research brief naming the scope, the
     evidence to cite, and the deliverable.
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

3. **Dispatch** as one job: one background Bash task with a 30-minute cap,
   named for the round (`consult-r1`, then `consult-r2`). Return as soon as
   it is running; the task completing is the signal, and nothing the dispatch
   prints needs relaying. With no voice named, the round is one turn on the
   default:

   ```sh
   envoy run consult-r1 --with codex:gpt-6-astra:high --prompt-file <brief> \
     --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 30
   ```

   [VOICE.md](VOICE.md) holds every voice's standing rules, so the brief
   carries only the problem. If envoy refuses it beside a warm voice that
   started without it, drop the flag and open the brief with that path.

   Take the voices the user names, one `--with` each. Voices
   with different jobs each take their own file as `<voice>=<brief>`, still
   one job with one collect, since a voice reads past an assignment paragraph
   inside a shared brief. A voice without its own file takes `--prompt-file`:

   ```sh
   envoy run consult-r1 --with claude:claude-fable-5-1=<critique-brief> --with codex:gpt-6-astra:high=<survey-brief> \
     --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 30
   ```

   If the completion notice is lost to a compaction or restart, `envoy
   pending` says what still needs attention.

4. **Collect** on the completion notice: `envoy collect consult-r1` prints the
   status and `result.md`, one section per member for a fan-out. Any other
   status prints a `next:` line; follow it. Done when every voice is
   collected or accounted for. A `partial` fan-out means one voice returned
   nothing, and its section says what to do.

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
     case, a failure path, a contract that invites misuse) adds or sharpens
     a planned case in the spec's test plan, starting the plan if needed.
     With no spec yet, carry the case into the synthesis for `/write-spec`. Points
     with nothing executable behind them are adopted as prose.
   - **Tenets** a voice returns meet the lesson's bar or count as tips.
     Revise survivors into the spec's `## Tenets` in place, or carry them in
     the synthesis for `/write-spec` when there is no spec; one left in the
     conversation is lost at compaction. The synthesis records each struck
     tenet and why, beside the test-plan edits.

   Done when every point is adopted (with its planned case where the trap
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

   Send the payload into the same sessions, which keep their round-1 context,
   with the `resume:` command the collect printed, a fresh name
   (`consult-r2`), and the payload as its prompt file: still one task and one
   collect. Done when the trigger
   is answered: the observation reported, the withheld position judged, or
   the conflict resolved to one position or an explicit fork.

7. **Synthesize** for the user, who did not watch the round and decides from
   this message alone.

   - Lead with each unresolved judgment call as its own question: why it
     matters now, what it means in product terms, the options and what each
     implies for the person using the product, and your recommendation. Use
     none of the round's vocabulary, and never refer the user back to
     earlier questions.
   - A problem the voice replaced or found unsupported is a decision, so it
     leads, with what settled it. A confirmed problem is one line among the
     convergences.
   - Then the convergences, the deltas adopted and why, the findings
     rejected and why, the test-plan edits, and any tenets adopted and where
     they were written.
   - Name the latest round and, for a fan-out, every member
     (`consult-r2/codex-gpt-6-astra`), and say which voice's position the
     design followed. A later `/review` seats that voice warm
     (`--with @consult-r2/codex-gpt-6-astra`).

   Done when every open decision stands on its own, and a cause the round
   could not settle names the observation that would settle it.

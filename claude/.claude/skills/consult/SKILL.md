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
with astra", "consult astra and fable". With no voice named, it is fable.

| name | `--with` | member name |
|---|---|---|
| **fable**, "claude", or none named | `claude:claude-fable-5-2` | `claude-claude-fable-5-2` |
| **astra**, "codex" | `codex:gpt-6.2-astra:high` | `codex-gpt-6.2-astra` |
| **carbon**, "gemini" | `agy:gemini-4-carbon:high` | `agy-gemini-4-carbon` |

```sh
envoy run consult-r1 --with claude:claude-fable-5-2 --prompt-file <brief> \
  --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 45
```

Two names are one job with two `--with`. Any other model, effort or brief
split: § More control.

## Process

1. **Take a position**: what you would defend if no voice replied, worked
   through from the user's latest input; open questions go into the brief.

   - **The problem**: what is wrong or needed and why, as a chain of links,
     each marked observed or inferred, plus what you never checked. A cause
     read in the code is observed; one reached from an incident, a log or a
     correlation is inferred, however sure you are. For a need, what someone
     reported, and who, is observed; what to build is inferred.
   - **The approach**: the shape you would ship tomorrow, the shape you
     discarded, and which earlier conclusions the new input broke.

   Done when every "because" is marked.

2. **Write the brief** from [BRIEF.md](BRIEF.md), which says what each
   section holds; [VOICE.md](VOICE.md) rides beside it with every voice's
   standing rules. Decide step 5's withhold first, since it removes our
   position from this round's brief. A voice with one job gets a brief cut
   to it: one sent only to pin the cause loses the shape (the read's second
   item, "What we propose", output items 4 to 6), one sent only to judge the
   shape loses the ranked causes and the falsifying observation, and a
   survey voice gets its own research brief naming the scope, the evidence
   to cite and the deliverable. Done when a cold reader could act on the
   brief without this conversation, and nothing above the voice's read
   states a cause, fix or design.

3. **Dispatch** the round's command (§ Voices) as one background Bash task
   named for the round (`consult-r1`, then `consult-r2`), and return. On the
   completion notice, `envoy collect consult-r1` prints every voice's
   result.

4. **Judge every point.** Adopt it, or rebut it with the reason (missing
   context, wrong target, technically wrong); one you cannot resolve goes to
   the user with both positions. Silently deferring to a voice and silently
   overriding it are the same failure.

   - **Order.** The voice's method first: settle a disputed count by running
     its variant, and revise the position if it changes. Then its read and
     its problem verdict, before any design point. Independent convergence on
     our problem is the strongest evidence a round gives; a different problem
     is settled before the shape.
   - **Carbon's numbers.** Carbon states unmeasured numbers as fact; check
     any a decision rests on.
   - **Causes.** Adopt a cause by running its falsifying observation, never
     by agreeing with it. A problem the evidence does not carry stays
     unsettled, and the next move is that observation, not a build.
   - **Several voices.** Agreement is not evidence, since voices share the
     brief's framing: judge each point before looking at who said it, and
     voices on different briefs each against its own. A real conflict is a
     fork for the user.
   - **Traps.** A point naming a trap the build could fall into sharpens an
     obligation in the spec's § Verification when something reaches the
     case, and is a non-goal when nothing does; with no spec yet, it goes
     into the synthesis.
   - **Tenets** a voice returns meet the lesson's bar or count as tips.
     Revise survivors into the spec's `## Tenets` in place, or carry them in
     the synthesis for `/write-spec` when there is no spec; one left in the
     conversation is lost at compaction.

5. **Round 2** opens only on one of these, into the same sessions through
   the `resume:` command the collect printed, named `consult-r2`:

   - **The falsifying observation came back.** Run the cheapest one the voice
     named and send what you saw; that round decides whether the cause holds.
   - **A wrong answer would cost a whole implementation cycle**: withhold
     across two turns. Round 1 sends the brief without "What we believe" and
     "Where we doubt it", asking for the voice's own method, read, problem,
     falsifier and approach. Round 2 sends those two sections and the output
     items that judge ours, against a reading the voice already committed to.
   - **A split fan-out.** Send both positions back and ask each voice to
     argue against the other's.

6. **Synthesize** for the user. A problem the voice replaced or found
   unsupported is a decision for them, with what settled it; a confirmed
   problem is one line among the convergences. Then the deltas adopted and
   why, the findings rejected and why, the obligation edits, and the tenets
   adopted or struck and where they were written. Name the latest round and,
   for a fan-out, each member (`consult-r2/codex-gpt-6.2-astra`), and say
   which voice's position the design followed; a later `/review` seats it
   warm. Done when a cause the round could not settle names the observation
   that would settle it.

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
  --instructions-file ~/.agents/skills/consult/VOICE.md --timeout-min 45
```

---
name: consult
description: "Put this session's thinking on trial before a fresh AI session (codex or claude) — diagnosis (is the cause right, before the fix) or approach (is this the shape to build) — then synthesize the deltas."
---

# Consult — independent second opinions

You are the lead. Fresh sessions ("voices") give independent takes on a problem this conversation already understands; you collect their designs and synthesize. Voices are peers, not authorities — adopt what survives your scrutiny, push back on what doesn't.

Dispatching, patterns, and house rules: [DISPATCH.md](../envoy/DISPATCH.md).

## Process

1. **Take a position** — dispatch _from_ a position, never toward one. The user has just answered your open questions, added requirements, or moved the target; work that through yourself and land on what you would defend if no voice ever replied. Open questions survive into the brief — a position held with reservations is still a position — but handing over an undigested pile of answers buys back an answer you have no standing to judge.

   What the position *is* follows what is on trial:

   - **A design choice** → the design you would ship tomorrow: what the goal now is, what you would build, the shape you discarded to get there, and which of your earlier conclusions the new input broke.
   - **A causal claim** → the belief and its grounds: the causal chain you think explains the symptom, link by link; which links you *observed* and which you inferred; and the line that costs the most to write honestly — **what you never checked**. A session that has been debugging for an hour holds this implicitly and has usually never stated it; stating it is what makes it attackable.

   Done when that paragraph exists, and — for a causal claim — when observed and inferred are separated in it.

2. **Pick the mode, then write the brief.** One question divides them: **is a causal claim on trial?** With one, the cause is judged before the fix; without one, there is nothing to falsify and the shape is the whole question. Route on what the user's words say, wherever in the turn they fall: this skill is invoked by file path as readily as by `/consult`, so an arguments block is not always there to read.

   | the turn says | on trial | mode |
   |---|---|---|
   | a cause believed rather than proven — a hypothesis, a suspicion, "I think it's X because Y", a symptom nobody has traced yet | a causal claim | **diagnosis** |
   | a shape to commit to — "settle the final approach", which interface, a spec or design doc, a scope call, or a bug whose cause is already read out of the code | a design choice | **approach** |

   A bug in the picture is not the signal; an **unsettled cause** is. A session that has traced the mechanism and can point at the lines has no causal claim left on trial, however loud the incident was — there the fix is the whole question and `approach` is the instrument.

   **diagnosis** ([DIAGNOSIS-BRIEF.md](DIAGNOSIS-BRIEF.md)) — the cause goes on trial before the fix, and the brief's **order is the instrument**: what was observed, then the voice's **blind read** of it, then what this session concluded. Filling that first section costs the most care — every line is something someone saw, and one inference among them spends what the round was bought for. Where a wrong diagnosis would cost a whole implementation cycle, step 6 splits the blind read across two turns instead.

   **approach** ([APPROACH-BRIEF.md](APPROACH-BRIEF.md)) — the voice critiques the shape: the position you just took, or an artifact the reading list points at (a spec, a design doc, a glossary). Blindness is neither possible nor the goal here; separating decided from open is.

   **The fence rule.** A brief may fence off settled items, but a fence is legitimate only over what something **outside this session** has already judged — a spec the user approved, a decision they made, a platform constraint. Analysis this session produced an hour ago is not settled direction however confident it is; fencing it hands the voice a conclusion nobody has judged and asks it to critique the execution of it, which is how a round comes back approving the wrong problem. That material goes in as the proposal, where it can be attacked.

   The codebase-design lesson pointers (`~/.config/lessons/codebase-design/…`) go out as the template writes them whenever module shape or an interface is at stake; trim them only when the question genuinely isn't about code structure. Any rulebook this session is working under goes out beside them by path — the voice works to the same bar the work will be held to. Done when a cold reader could act on the brief without this conversation, and when nothing above the diagnosis brief's blind read states a conclusion.

3. **Dispatch** as one fan-out, 30-minute cap — the same brief to every voice, one task that finishes once:

   ```sh
   envoy fan --prompt-file <brief> --with codex --with claude:opus --timeout-min 30 --label consult --coordinate-file <scratchpad>/consult.coords
   ```

   Two voices is the default because independent disagreement is the product: where they diverge is the finding, and step 5 is built to judge that fork. Take the voices the user names; where they name none, codex plus one Claude model. Collapse to a single turn when the user asks for one voice, or when the question is narrow enough that a second read buys nothing:

   ```sh
   envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult --coordinate-file <scratchpad>/consult.coords
   ```

   Read the coordinate file once, relay out-dir and watch, then return.

4. **Collect** on the task-completion notification — `envoy collect <out-dir>` prints the status block and `result.md`; for a fan-out it prints every voice in one block, split by model (once — a persisted output is read afterwards). Done when every dispatched voice is collected or explicitly accounted for — a `partial` fan-out means one voice returned nothing, and that voice's section says what to do about it.

5. **Analyze critically**, point by point: valid → adopt it; wrong → say why (missing context, wrong optimization target, or technically incorrect). A voice that restated the goal differently than you framed it found something before it designed anything — settle that disagreement first, since every design judgment downstream of it is being made against a different target. A fundamental disagreement you cannot resolve → present both positions to the user for judgment; silently deferring to the voice and silently overriding it are equal failures.

   With several voices, judge each point on its merits before you look at who said it: two voices agreeing is not evidence — they may share a blind spot or the brief's own framing — and a point only one voice raised can be the most valuable thing in the round. Where they genuinely conflict, that fork is the finding; carry it to the user as one.

   In `diagnosis`, read the **blind read** first and treat its **delta** against our hypothesis as the finding. Converging independently on the same cause is the strongest evidence this round can produce; landing elsewhere means one of you is weighing evidence the other isn't, and settling that comes before a word about the fix. A cause verdict is adopted by **running the falsifying observation**, never by agreeing with it — that observation is this mode's counterpart of the planned test case below, and step 6 is where its result goes back.

   Adoption has a second half when the point names a trap the implementation could fall into — an edge case, a failure path, a contract that invites misuse. There is no code to pin it against yet, so pin it in the spec's test plan: add or sharpen the planned case that would catch exactly that trap, starting the plan if the spec lacks one. Prose absorbs a point and fades by implementation time; a planned case is what the eventual suite gets held against. Points with nothing executable behind them — naming, structure, scope, docs — are adopted as prose alone.

   Done when every point carries a disposition: adopted (with its planned case where the trap was executable), rebutted with the reason, or escalated to the user.

6. **Round 2** has three real triggers, beyond "depth warrants it". In `diagnosis`: **the falsifying observation coming back** — run the cheapest one the voice named, then send what you saw; that is the round where a hypothesis dies or survives, and it is worthless before the observation exists. Also in `diagnosis`, where a wrong cause would cost a whole implementation cycle: **split the blind read across the two turns** — round 1 carries the evidence with our hypothesis withheld entirely, round 2 sends it in, and the voice judges it against a reading it has already committed and cannot now un-see. In `approach`: a split fan-out, where the voices genuinely conflicted — send both positions back and ask each to argue against the other's. Either way the payload is the host position or updated proposal, sent into the same session(s) for critique-and-confirm — the voices keep their round-1 context, where a fresh session would restart from zero. Done when the trigger that opened the round is answered: the observation reported, the withheld hypothesis judged, or the conflict resolved to one position or an explicit fork. One voice: `envoy collect` prints the resume command. A fan-out continues whole — still one task, one collect:

   ```sh
   envoy fan --resume-from <out-dir> --prompt-file round2.md --timeout-min 30 --label consult-r2
   ```

7. **Synthesize** for the user: where the voices converged with the host position, the deltas adopted and why, the findings rejected and why, and any unresolved judgment calls. A `diagnosis` round leads with the cause — confirmed, refuted, or replaced, what settled it, and the blind read's delta, including when it converged — before anything about the fix. Name the out-dir in the synthesis — and, for a fan-out, each member's directory (`<out-dir>/codex`, `<out-dir>/claude-opus`): the sessions stay continuable, and when /review later covers the implementation of this design, its default seats one of those voices warm (`--with-from <member-dir>`) beside a cold one, so the synthesis also says which voice's position the design followed.

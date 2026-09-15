---
name: consult
description: "Put this session's thinking on trial before a fresh AI session (codex or claude) — diagnosis (is the cause right, before the fix) or approach (is this the shape to build) — then synthesize the deltas."
requires:
  - lessons:codebase-design/deep-modules.md
  - lessons:collaboration/tenets.md
---

# Consult — independent second opinions

You are the lead. Fresh sessions ("voices") give independent takes on a problem this conversation already understands; you collect their designs and synthesize. Voices are peers, not authorities — adopt what survives your scrutiny, push back on what doesn't.

## Process

1. **Take a position** — dispatch _from_ a position, never toward one. The user has just answered your open questions, added requirements, or moved the target; work that through yourself and land on what you would defend if no voice ever replied. Open questions survive into the brief — a position held with reservations is still a position — but handing over an undigested pile of answers buys back an answer you have no standing to judge.

   What the position *is* follows what is on trial:

   - **A design choice** → the design you would ship tomorrow: what the goal now is, what you would build, the shape you discarded to get there, and which of your earlier conclusions the new input broke.
   - **A causal claim** → the belief and its grounds: the causal chain you think explains the symptom, link by link; which links you *observed* and which you inferred; and the line that costs the most to write honestly — **what you never checked**, which is what makes the claim attackable.

   Done when that paragraph exists, and — for a causal claim — when observed and inferred are separated in it.

2. **Pick the mode, then write the brief** — one self-contained file in the session scratchpad, from the mode's template; one file per question, so voices the user gave different jobs get different briefs. The templates cover a critique and a diagnosis; a voice sent to survey — what other products do, what a library offers — takes a self-contained research brief of its own that names the scope, the evidence it must cite, and the deliverable. One question divides the modes: **is a causal claim on trial?** With one, the cause is judged before the fix; without one, there is nothing to falsify and the shape is the whole question. Route on what the user's words say, wherever in the turn they fall: this skill is invoked by file path as readily as by `/consult`, so an arguments block is not always there to read.

   | the turn says | on trial | mode |
   |---|---|---|
   | a cause believed rather than proven — a hypothesis, a suspicion, "I think it's X because Y", a symptom nobody has traced yet | a causal claim | **diagnosis** |
   | a shape to commit to — "settle the final approach", which interface, a spec or design doc, a scope call, or a bug whose cause is already read out of the code | a design choice | **approach** |

   A bug in the picture is not the signal; an **unsettled cause** is. A session that has traced the mechanism and can point at the lines has no causal claim left on trial, however loud the incident was — there the fix is the whole question and `approach` is the instrument.

   **diagnosis** ([DIAGNOSIS-BRIEF.md](DIAGNOSIS-BRIEF.md)) — the cause goes on trial before the fix, and the brief's **order is the instrument**: what was observed, then the voice's **blind read** of it, then what this session concluded. Filling that first section costs the most care — every line is something someone saw, and one inference among them spends what the round was bought for. Where a wrong diagnosis would cost a whole implementation cycle, step 6 splits the blind read across two turns instead.

   **approach** ([APPROACH-BRIEF.md](APPROACH-BRIEF.md)) — the voice judges the shape: the position you just took, or an artifact the reading list points at (a spec, a design doc, a glossary). Its order is the instrument too: the goal and what must be true, then the reading list, then the voice's own **sketch** of what it would build, and only then our position as one paragraph to attack and the areas we doubt. The delta between its sketch and ours is the product; a voice that starts from our design critiques inside its frame, and its opening "the real problem matches your framing" is worth nothing. The template says what a doubt and a probe must be. Same-file ordering is a nudge, not blinding; step 6 says when the position is withheld for a second turn instead.

   **The fence rule.** A brief may fence off settled items, but a fence is legitimate only over what something **outside this session** has already judged — a spec the user approved, a decision they made, a platform constraint. Analysis this session produced an hour ago is not settled direction however confident it is, and the user agreeing with it fences nothing — "agree with the general direction, settle the approach" names what to put on trial, not what to protect; fencing it hands the voice a conclusion nobody has judged and asks it to critique the execution of it, which is how a round comes back approving the wrong problem. That material goes in as the proposal, where it can be attacked.

   **Tenets.** When the turn asks how the build should proceed — "guidelines", "principles", "guardrails", a milestone or a phase plan — keep the approach brief's tenets item; delete it otherwise. Its form is `~/.config/lessons/collaboration/tenets.md`: the few load-bearing decisions with their reasons, never rules about files, which is what a voice returns when the word is left undefined.

   The template's design-bar section goes out as written — its lesson pointers are for the voice — whenever module shape or an interface is at stake; trim it only when the question genuinely isn't about code structure. Any rulebook this session is working under goes out beside them by path — the voice works to the same bar the work will be held to. Done when a cold reader could act on the brief without this conversation, and when nothing above the diagnosis brief's blind read states a conclusion.

3. **Dispatch** as one fan-out, 30-minute cap — each voice on its brief, one background Bash task, the job named for the round (`consult-r1`, then `consult-r2`), that finishes once; return as soon as it is running, since the task completing is the signal and nothing the dispatch prints needs relaying:

   ```sh
   envoy run consult-r1 --with codex --with claude:opus --prompt-file <brief> --timeout-min 30
   ```

   Two voices buy what one cannot — independent disagreement is the product: where they diverge is the finding, and step 5 is built to judge that fork. Take the voices the user names, however they name them. `codex` alone inherits the model in the user's Codex config; a Claude voice is spelled `claude:<model>` — "opus" is `claude:opus`, "fable" is `claude:claude-fable-5-1` — and runs only on a model the user named, so where they name no voice the round is one codex turn, never a Claude model of your choosing. The single turn also fits a question narrow enough that a second read buys nothing:

   ```sh
   envoy run consult-r1 --with codex --prompt-file <brief> --timeout-min 30
   ```

   When the user gives the voices different jobs — one to judge the design, one to survey what exists — each voice takes its own brief, attached as `<voice>=<brief>`, and it is still one job with one collect:

   ```sh
   envoy run consult-r1 --with claude:claude-fable-5-1=<critique-brief> --with codex=<survey-brief> --timeout-min 30
   ```

   A voice with its own job gets its own file: an assignment paragraph inside a shared brief is read past, and the voice does the other's work. `--prompt-file` stays the default for any voice without a file of its own.

   If the completion notification is lost to a compaction or a restart, `envoy pending` says what still needs attention.

4. **Collect** on the task-completion notification — `envoy collect consult-r1` prints the status block and `result.md`; for a fan-out, one section per member, each headed with the member's name. Any other status prints a `next:` line instead — follow it. Done when every dispatched voice is collected or explicitly accounted for — a `partial` fan-out means one voice returned nothing, and that voice's section says what to do about it.

5. **Analyze critically**, point by point: valid → adopt it; wrong → say why (missing context, wrong optimization target, or technically incorrect). A voice that restated the goal differently than you framed it found something before it designed anything — settle that disagreement first, since every design judgment downstream of it is being made against a different target. A fundamental disagreement you cannot resolve → present both positions to the user for judgment; silently deferring to the voice and silently overriding it are equal failures.

   With several voices, judge each point on its merits before you look at who said it: two voices agreeing is not evidence — they may share a blind spot or the brief's own framing — and a point only one voice raised can be the most valuable thing in the round. Where they genuinely conflict, that fork is the finding; carry it to the user as one. Voices that took different briefs answered different questions: judge each against its own, and where their claims overlap — a survey finding what a critique called unavailable — compare them on their evidence rather than counting the agreement.

   In `diagnosis`, read the **blind read** first and treat its **delta** against our hypothesis as the finding. Converging independently on the same cause is the strongest evidence this round can produce; landing elsewhere means one of you is weighing evidence the other isn't, and settling that comes before a word about the fix. A cause verdict is adopted by **running the falsifying observation**, never by agreeing with it — that observation is this mode's counterpart of the planned test case below, and step 6 is where its result goes back.

   Adoption has a second half when the point names a trap the implementation could fall into — an edge case, a failure path, a contract that invites misuse. There is no code to pin it against yet, so pin it in the spec's test plan: add or sharpen the planned case that would catch exactly that trap, starting the plan if the spec lacks one, and where no spec exists yet carrying the cases into the synthesis for `/write-spec` to pick up — a planned case is what the eventual suite gets held against, where prose fades by implementation time. Points with nothing executable behind them — naming, structure, scope, docs — are adopted as prose alone.

   Tenets a voice returns are judged by the lesson's bar rather than as points: a line that fails it is a tip and takes a disposition like any other point. Survivors go where the build rereads — into the spec's `## Tenets`, next to its phases, when a spec exists, creating the section or revising it with each struck tenet and its reason kept, committed with the test-plan edits; otherwise into the synthesis beside the planned cases for `/write-spec` to place there. A tenet left in this conversation is dropped at the next compaction.

   Done when every point carries a disposition: adopted (with its planned case where the trap was executable), rebutted with the reason, or escalated to the user.

6. **Round 2** has real triggers, beyond "depth warrants it". In `diagnosis`: **the falsifying observation coming back** — run the cheapest one the voice named, then send what you saw; that is the round where a hypothesis dies or survives, and it is worthless before the observation exists. In either mode, where a wrong answer would cost a whole implementation cycle, **withhold across two turns** — this is the one home of that trigger. In `diagnosis` round 1 carries the evidence with our hypothesis withheld entirely and round 2 sends it in; in `approach` round 1 carries the goal, the constraints and the reading list and returns the voice's own sketch, and round 2 sends our position in. Either way the voice judges what arrives against a reading it has already committed and cannot now un-see. In `approach`: a split fan-out, where the voices genuinely conflicted — send both positions back and ask each to argue against the other's. Another trigger arrives from outside: `/write-spec` continues a finished round with its spec as the updated proposal under critique — a legitimate round 2, same resume mechanics. Either way the payload is the host position or updated proposal, sent into the same session(s) for critique-and-confirm — the voices keep their round-1 context, where a fresh session would restart from zero. Done when the trigger that opened the round is answered: the observation reported, the withheld hypothesis judged, or the conflict resolved to one position or an explicit fork. One voice or a whole fan-out continues the same way — still one task, one collect — with the `resume:` command collection printed: a fresh name (`consult-r2`) and the payload as its prompt file.

7. **Synthesize** for the user, who did not watch the round and decides from this message alone. Lead with what needs them: each unresolved judgment call as its own standalone question — why it matters now, what it means in plain product terms, the options with what each implies for the person using the product, and your recommendation — with none of the vocabulary the round built; a synthesis that ends on "your earlier questions stand as before" sends the user back to reconstruct them. Then where the voices converged with the host position, the deltas adopted and why, the findings rejected and why, and — when the round carried the tenets item — the tenets adopted and where they were written. A `diagnosis` round leads with the cause — confirmed, refuted, or replaced, what settled it, and the blind read's delta, including when it converged — before anything about the fix. Name the job in the synthesis — the latest round, and for a fan-out its members (`consult-r1/codex`, `consult-r1/claude-opus`; after a round 2, `consult-r2/codex`): the sessions stay continuable, and when /review later covers the implementation of this design, its default seats one of those voices warm (`--with @consult-r2/codex`) beside a cold one, so the synthesis also says which voice's position the design followed.

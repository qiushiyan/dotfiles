---
name: consult
description: "Put this session's thinking on trial before a fresh AI session (codex or claude) — is the problem what we think it is, and is this the shape to build — then synthesize the deltas."
requires:
  - lessons:codebase-design/deep-modules.md
  - lessons:collaboration/tenets.md
---

# Consult — independent second opinions

You are the lead. Fresh sessions ("voices") give independent takes on a problem this conversation already understands; you collect them and synthesize. Every voice does two jobs in one answer: it defines the problem — confirming ours, sharpening it, or finding that we defined the wrong one — and then judges the approach, built on whichever problem survived. Where it agrees with our reading, its effort goes to the shape; where its own exploration finds a different cause or a different problem, it says so first and designs from there. Voices are peers, not authorities — adopt what survives your scrutiny, push back on what doesn't.

## Resolving the voice

Name the model on every cold voice, so the job records what ran whatever the provider's config holds that day. Resolve it from the user's words:

```sh
--with codex:gpt-6-astra         # the default: no voice named, "codex", or "astra"
--with codex:gpt-6-sol           # "sol"
--with claude:claude-opus-5-5    # "claude", "opus"
--with claude:claude-fable-5-1   # "fable"
--with codex:gpt-6-astra:high    # effort only when the user asks: "astra on high"
--with codex:gpt-6-sol:high      # "sol on high"
```

A model ID the user spells out goes through as written. A warm voice (`@<job>/<member>`) keeps the model it started on.

## Process

1. **Take a position** — dispatch _from_ a position, never toward one. The user has just answered your open questions, added requirements, or moved the target; work that through yourself and land on what you would defend if no voice ever replied. Open questions survive into the brief — a position held with reservations is still a position — but handing over an undigested pile of answers buys back an answer you have no standing to judge.

   The position has two parts. **The problem** — what is wrong or needed and why, as a chain of links, each marked observed (where you saw it) or inferred, and the line that costs the most to write honestly: **what you never checked**. A cause you read out of the code is an observed link; a cause you reached from an incident, a log or a correlation is inferred, however confident you are. For a need, what someone reported — and who — is observed; what to build from it is inferred. **The approach** — the shape you would ship tomorrow, the shape you discarded to get there, and which of your earlier conclusions the new input broke.

   Done when both parts exist and every "because" in them is marked observed or inferred.

2. **Write the brief** — one self-contained file in the session scratchpad, from [BRIEF.md](BRIEF.md). Decide step 6's withhold first, since it removes "What we believe" from this round's brief. One file per question, so voices the user gave different jobs get different briefs: a voice sent only to pin the cause gets the brief without the shape — its read's second item, "What we propose", and output items 4 to 6 — and a voice sent only to judge the shape gets it without the causal items: the ranked causes in its read, and the falsifying observation. A voice sent to survey — what other products do, what a library offers — takes a self-contained research brief of its own that names the scope, the evidence it must cite, and the deliverable.

   **What we observe** carries everything someone saw that the position rests on, above the voice's read; the explanations wait for "What we believe". Filling it costs the most care — one inference among the observations spends the independence the round was bought for. It is deleted only when the position rests on reasoning alone, never because the cause feels settled: a cause the session believes is exactly what a second reader should check.

   **The fence rule.** A brief may fence off settled items, but a fence is legitimate only over what something **outside this session** has already judged — a spec the user approved, a decision they made, a platform constraint. Analysis this session produced an hour ago is not settled direction however confident it is, and the user agreeing with it fences nothing — "agree with the general direction, settle the approach" names what to put on trial, not what to protect; fencing it hands the voice a conclusion nobody has judged and asks it to critique the execution of it, which is how a round comes back approving the wrong problem. That material goes in under "What we believe", where it can be attacked.

   **Tenets.** When the turn asks how the build should proceed — "guidelines", "principles", "guardrails", a milestone or a phase plan — keep the brief's tenets item; delete it otherwise. Its form is `~/.config/lessons/collaboration/tenets.md`, which the item sends the voice to before it writes.

   The template's design-bar section goes out as written — its lesson pointers are for the voice — whenever module shape or an interface is at stake; trim it only when the question genuinely isn't about code structure. Any rulebook this session is working under goes out beside them by path — the voice works to the same bar the work will be held to.

   **A position that rests on a number this session measured** carries [DATA-BLOCK.md](DATA-BLOCK.md)'s bullets inside "What we observe" and keeps the output's method item, with the queries and raw outputs saved beside the brief; the voice judges the method before the conclusion. No such number: delete the method item.

   Done when a cold reader could act on the brief without this conversation, when nothing above the voice's read states a cause, a fix or a design, and when every count the position leans on has its query on disk.

3. **Dispatch** as one job, 30-minute cap — each voice on its brief, one background Bash task, the job named for the round (`consult-r1`, then `consult-r2`), that finishes once; return as soon as it is running, since the task completing is the signal and nothing the dispatch prints needs relaying. Where the user names no voice the round is one turn on the default:

   ```sh
   envoy run consult-r1 --with codex:gpt-6-astra --prompt-file <brief> --timeout-min 30
   ```

   Two voices buy what one cannot — independent disagreement is the product: where they diverge is the finding, and step 5 is built to judge that fork. Take the voices the user names, resolved per **Resolving the voice**. When a codex and a Claude voice are both named:

   ```sh
   envoy run consult-r1 --with codex:gpt-6-astra --with claude:claude-opus-5-5 --prompt-file <brief> --timeout-min 30
   ```

   When the user gives the voices different jobs — one to judge the design, one to survey what exists — each voice takes its own brief, attached as `<voice>=<brief>`, and it is still one job with one collect:

   ```sh
   envoy run consult-r1 --with claude:claude-fable-5-1=<critique-brief> --with codex:gpt-6-astra=<survey-brief> --timeout-min 30
   ```

   A voice with its own job gets its own file: an assignment paragraph inside a shared brief is read past, and the voice does the other's work. `--prompt-file` stays the default for any voice without a file of its own.

   If the completion notification is lost to a compaction or a restart, `envoy pending` says what still needs attention.

4. **Collect** on the task-completion notification — `envoy collect consult-r1` prints the status block and `result.md`; for a fan-out, one section per member, each headed with the member's name. Any other status prints a `next:` line instead — follow it. Done when every dispatched voice is collected or explicitly accounted for — a `partial` fan-out means one voice returned nothing, and that voice's section says what to do about it.

5. **Analyze critically**, point by point: valid → adopt it; wrong → say why (missing context, wrong optimization target, or technically incorrect). A fundamental disagreement you cannot resolve → present both positions to the user for judgment; silently deferring to the voice and silently overriding it are equal failures.

   Judge the voice's **method** item first when there is one: a count it disputes is settled by running its variant, and a changed count revises the position before anything else is judged. Then its **read**, and its **problem verdict** before any design point. Its delta against our position is the finding: converging independently on the same problem is the strongest evidence this round can produce; landing elsewhere means one of you is weighing evidence the other isn't, and settling that comes before a word about the shape, since every design judgment downstream of it is being made against a different target. A cause is adopted by **running the falsifying observation** and reading what it shows, never by agreeing with it — that observation is the cause's counterpart of the planned test case below, and step 6 is where its result goes back. A problem the voice found not carried by the evidence stays unsettled: the next move is the observation that would settle it, not a build.

   With several voices, judge each point on its merits before you look at who said it: two voices agreeing is not evidence — they may share a blind spot or the brief's own framing — and a point only one voice raised can be the most valuable thing in the round. Where they genuinely conflict, that fork is the finding; carry it to the user as one. Voices that took different briefs answered different questions: judge each against its own, and where their claims overlap — a survey finding what a critique called unavailable — compare them on their evidence rather than counting the agreement.

   Adoption has a second half when the point names a trap the implementation could fall into — an edge case, a failure path, a contract that invites misuse. There is no code to pin it against yet, so pin it in the spec's test plan: add or sharpen the planned case that would catch exactly that trap, starting the plan if the spec lacks one, and where no spec exists yet carrying the cases into the synthesis for `/write-spec` to pick up — a planned case is what the eventual suite gets held against, where prose fades by implementation time. Points with nothing executable behind them — naming, structure, scope, docs — are adopted as prose alone.

   Tenets a voice returns are judged by the lesson's bar rather than as points: a line that fails it is a tip and takes a disposition like any other point. Survivors go where the build rereads — into the spec's `## Tenets`, where the spec bar places it, when a spec exists, creating the section or revising it in place, with each struck tenet and its reason recorded in this round's synthesis, alongside the test-plan edits; otherwise into the synthesis beside the planned cases for `/write-spec` to place there. A tenet left in this conversation is dropped at the next compaction.

   Done when every point carries a disposition: adopted (with its planned case where the trap was executable), rebutted with the reason, or escalated to the user.

6. **Round 2** has real triggers, beyond "depth warrants it":

   - **The falsifying observation came back.** Run the cheapest one the voice named, then send what you saw; that is the round where a cause dies or survives, and it is worthless before the observation exists.
   - **A wrong answer would cost a whole implementation cycle** — **withhold across two turns**; this is the one home of that trigger. Round 1 carries everything down to the reading list with "What we believe" deleted and returns the voice's read and its own analysis; round 2 sends our position in. The voice judges it against a reading it has already committed and cannot now un-see.
   - **A split fan-out**, where the voices genuinely conflicted — send both positions back and ask each to argue against the other's.
   - **From outside:** `/write-spec` continues a finished round with its spec as the updated proposal under critique — same resume mechanics.

   The payload goes into the same session(s) for critique-and-confirm — the voices keep their round-1 context, where a fresh session would restart from zero. One voice or a whole fan-out continues the same way — still one task, one collect — with the `resume:` command the collect printed: a fresh name (`consult-r2`) and the payload as its prompt file. Done when the trigger that opened the round is answered: the observation reported, the withheld position judged, or the conflict resolved to one position or an explicit fork.

7. **Synthesize** for the user, who did not watch the round and decides from this message alone. Lead with what needs them: each unresolved judgment call as its own standalone question — why it matters now, what it means in plain product terms, the options with what each implies for the person using the product, and your recommendation — with none of the vocabulary the round built; a synthesis that ends on "your earlier questions stand as before" sends the user back to reconstruct them. Then where the voices converged with the host position, the deltas adopted and why, the findings rejected and why, and — when the round carried the tenets item — the tenets adopted and where they were written. A problem the voice replaced or found unsupported is a decision and leads with the others, with what settled it; a confirmed problem is one line among the convergences, including when the voice reached it independently. Name the job in the synthesis — the latest round, and for a fan-out its members (`consult-r1/codex-gpt-6-astra`, `consult-r1/claude-claude-opus-5-5`; after a round 2, `consult-r2/codex-gpt-6-astra`): the sessions stay continuable, and when /review later covers the implementation of this design, its default seats one of those voices warm (`--with @consult-r2/codex-gpt-6-astra`) beside a cold one, so the synthesis also says which voice's position the design followed.

   Done when the user can decide from this message alone: every open decision stands on its own, and a cause the round could not settle names the observation that would settle it.

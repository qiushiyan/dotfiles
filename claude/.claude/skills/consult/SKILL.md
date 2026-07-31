---
name: consult
description: "Get independent design takes from fresh AI sessions (codex or claude) on the problem at hand, then synthesize the deltas."
disable-model-invocation: true
---

# Consult — independent second opinions

You are the lead. Fresh sessions ("voices") give independent takes on a problem this conversation already understands; you collect their designs and synthesize. Voices are peers, not authorities — adopt what survives your scrutiny, push back on what doesn't.

Dispatching, patterns, and house rules: [DISPATCH.md](../envoy/DISPATCH.md).

## Process

1. **Write the brief** — one self-contained file in the session scratchpad, from [BRIEF-TEMPLATE.md](BRIEF-TEMPLATE.md). The voice starts cold: state the problem, the constraints, the repo paths to read, and the concrete questions. End with "Design analysis only — do not change any code". Pick the mode by what round 1 should produce:

   - **Design mode** — the voice designs a solution. Keep the brief **blind**: your and the user's current proposal stays out of round 1, so the voice designs unanchored instead of critiquing what it was handed. Blindness leaks through the framing faster than through prose — a question shaped "A or B?" hands back the very decision you were buying an independent take on, and a problem stated in your solution's vocabulary has already answered itself. The test before dispatch: could the voice infer your preferred answer from the questions you asked? Lead with the goal in the user's terms — what they want to be true once this works — and let the voice choose the altitude it solves at.
   - **Review mode** — the voice critiques an existing artifact (spec, design doc, glossary). It gets the artifact; blindness is neither possible nor the goal. Instead separate decided from open: list the settled decisions as not up for relitigation — the voice hunts defects in the *execution* — and allow objections to a decided item only with concrete evidence, clearly marked as foundational.

   The template's codebase-design lesson pointers (`~/.config/lessons/codebase-design/…`) go out as written whenever module shape or an interface is at stake; trim them only when the question genuinely isn't about code structure. Any rulebook this session is working under goes out beside them by path — the voice designs to the same bar the work will be held to. Done when a cold reader could act on the brief without this conversation.

2. **Dispatch** one voice, 30-minute cap:

   ```sh
   envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult
   ```

   More voices only when the user asks for them — and then as one fan-out, not several dispatches: the same brief goes to every voice, and one task finishes once:

   ```sh
   envoy fan --prompt-file <brief> --with codex --with claude:opus --timeout-min 30 --label consult
   ```

   Relay the coordinate block, then return.

3. **Collect** on the task-completion notification — `envoy collect <out-dir>` prints the status block and `result.md`; for a fan-out it prints every voice in one block, split by model. Done when every dispatched voice is collected or explicitly accounted for — a `partial` fan-out means one voice returned nothing, and that voice's section says what to do about it.

4. **Analyze critically**, point by point: valid → adopt it; wrong → say why (missing context, wrong optimization target, or technically incorrect). A voice that restated the goal differently than you framed it found something before it designed anything — settle that disagreement first, since every design judgment downstream of it is being made against a different target. A fundamental disagreement you cannot resolve → present both positions to the user for judgment; silently deferring to the voice and silently overriding it are equal failures.

   With several voices, judge each point on its merits before you look at who said it: two voices agreeing is not evidence — they may share a blind spot or the brief's own framing — and a point only one voice raised can be the most valuable thing in the round. Where they genuinely conflict, that fork is the finding; carry it to the user as one.

   Adoption has a second half when the point names a trap the implementation could fall into — an edge case, a failure path, a contract that invites misuse. There is no code to pin it against yet, so pin it in the spec's test plan: add or sharpen the planned case that would catch exactly that trap, starting the plan if the spec lacks one. Prose absorbs a point and fades by implementation time; a planned case is what the eventual suite gets held against. Points with nothing executable behind them — naming, structure, scope, docs — are adopted as prose alone.

   Done when every point carries a disposition: adopted (with its planned case where the trap was executable), rebutted with the reason, or escalated to the user.

5. **Round 2, when depth warrants it**: send the host position or updated proposal into the same session(s) for critique-and-confirm — the voices keep their round-1 context, where a fresh session would restart from zero. One voice: `envoy collect` prints the resume command. A fan-out continues whole — still one task, one collect:

   ```sh
   envoy fan --resume-from <out-dir> --prompt-file round2.md --timeout-min 30 --label consult-r2
   ```

6. **Synthesize** for the user: where the voices converged with the host position, the deltas adopted and why, the findings rejected and why, and any unresolved judgment calls. Name the out-dir in the synthesis: the session stays continuable, and when /review later covers the implementation of this design, its default folds this voice in warm (`--with-from <out-dir>`) beside a cold one.

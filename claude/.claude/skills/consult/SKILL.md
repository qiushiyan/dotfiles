---
name: consult
description: "Get independent design takes from fresh AI sessions (codex or claude) on the problem at hand, then synthesize the deltas."
disable-model-invocation: true
---

# Consult — independent second opinions

You are the lead. Fresh sessions ("voices") give independent takes on a problem this conversation already understands; you collect their designs and synthesize. Voices are peers, not authorities — adopt what survives your scrutiny, push back on what doesn't.

Engine: `node ~/.claude/skills/sidekick-runtime/turn.mjs`. Read [ENGINE.md](../sidekick-runtime/ENGINE.md) before passing a user-supplied `--model`/`--effort` value (the valid values differ per provider) and whenever a turn ends with a status other than `ok` (it maps each status to the recovery move).

## Process

1. **Write the brief** — one self-contained file in the session scratchpad. The voice starts cold, with none of this conversation: state the problem, the constraints, the repo paths it should read, and the concrete questions. End with "Design analysis only — do not change any code" (read-only is a prompt convention; the engine doesn't sandbox). Keep the brief **blind**: your and the user's current proposal stays out of round 1, so the voice designs unanchored instead of critiquing what it was handed. Done when a cold reader could act on the brief without this conversation.

2. **Dispatch** one background turn per voice, via Bash `run_in_background` (a voice can exceed the 10-minute foreground cap):

   ```
   node ~/.claude/skills/sidekick-runtime/turn.mjs \
     --provider codex --prompt-file <brief> --timeout-min 15 --label consult
   ```

   Default is exactly that: one codex voice, no `--model`/`--effort` flags — the user's codex config governs. Add voices only when asked; every voice gets the same brief and never another voice's output. A claude voice needs an explicit strong model (e.g. `--model opus`) — never your own session's default by accident. Echo each dispatch to the user: provider, effective model/effort, and the session id once printed.

3. **Collect** on the task notification: read the final block from the task output, then Read `result.md`. A status other than `ok` → ENGINE.md's status table. Done when every dispatched voice is collected or explicitly accounted for.

4. **Analyze critically**, point by point: valid → adopt it; wrong → say why (missing context, wrong optimization target, or technically incorrect). A fundamental disagreement you cannot resolve → present both positions to the user for judgment; never silently override the voice or silently adopt its pivot.

5. **Round 2, when depth warrants it**: send the host position or updated proposal into the **same session** (`--resume <sessionId from meta.json>`) for critique-and-confirm. The voice keeps its round-1 context; a fresh session would restart the exercise from zero.

6. **Synthesize** for the user: where the voices converged with the host position, the deltas adopted and why, the findings rejected and why, and any unresolved judgment calls.

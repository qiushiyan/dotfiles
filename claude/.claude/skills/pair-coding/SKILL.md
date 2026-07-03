---
name: pair-coding
disable-model-invocation: true
description: "Pair-code with Codex in a sibling tmux pane: design review before implementation, code review after."
---

# Pair-coding with Codex

Drive Codex in a sibling tmux pane for design and code review. Claude Code acts as lead — sending designs for review, critically analyzing feedback, updating plans, and coordinating implementation review.

## Prerequisites

- The user is in tmux with Claude Code running in a pane.
- A design document, high-level plan, or at minimum a clear proposal exists (as a file or in conversation context).

## Setup

```bash
PANE=$(codex-pane-setup)
tmux-wait-for-text -t "$PANE" -p '^›\s*$' -T 15
```

`codex-pane-setup` is idempotent: it reuses an existing sibling pane and skips launching Codex if it's already running. `tmux-wait-for-text` blocks until Codex's prompt is ready — a bare `›` alone on its line — instead of a fixed sleep, so it works the same whether Codex just started or was already sitting there. Tell the user when Codex is ready.

## Sending prompts

Always send text and Enter separately. Use `-l` for literal text:

```bash
tmux send-keys -t "$PANE" -l -- "prompt text"
sleep 0.5
tmux send-keys -t "$PANE" Enter
```

## Waiting for Codex to finish

Codex responses for design reviews often take 2-5 minutes as it explores the codebase.

```bash
tmux-wait-for-text -t "$PANE" -p '^›\s*$' -T 300 -i 3
```

This blocks until the prompt returns to a bare `›` on its own line — the same ready signal as setup — instead of polling on a fixed schedule. On timeout it exits 1 and prints the last captured text to stderr; decide whether to wait again or check in with the user.

Once it returns, capture the response since the prompt you sent — anchor on a short, distinctive fragment of it, since long or multiline input may wrap in the pane and won't match verbatim:

```bash
tmux capture-pane -t "$PANE" -p -J | sed -n '/<fragment of your sent prompt>/,$p' | sed '1d'
```

This avoids re-reading the whole session's scrollback on later rounds, since Codex stays in the same pane across both review phases.

## Phase 1: Design review (two rounds)

### Round 1: Initial review

Send the proposal to Codex for critical review. If a design doc exists, point Codex to it. If not, summarize the problem, root cause, and proposed fix directly in the prompt. Either way, the review principles are what matter:

- Think critically and holistically about the design
- Evaluate both technical merit and end-user impact
- Challenge assumptions and suggest alternatives
- Present multiple approaches with tradeoffs
- Do not change any code — review only

Example prompt (adapt based on what you have):

```
We are going to implement a feature in this codebase. The goal is to <one-liner summary>. Review the plan at <design-doc-path> with a critical mind. For points you support, provide technical suggestions or caveats when applicable. For points you disagree with, reason why with concrete suggestions. Focus on both technical merit and end-user impact. Don't be afraid to challenge assumptions or suggest alternatives.

DO NOT CHANGE ANY CODE YET. Step back and evaluate holistically. Don't patch a flawed design — identify the real problem and UX goal, then consider redesigning from first principles if needed. Present multiple approaches with their tradeoffs, elaborate your rationale, and don't shy away from large-scale changes when justified.
```

If there is no design doc, replace the file reference with an inline summary of the problem, root cause analysis, proposed approach, and files involved.

After receiving Codex's response, analyze it critically:

1. For each point, assess whether it is valid.
2. If valid, incorporate it and update the design (document or proposal).
3. If wrong, reason about why — missing context, wrong optimization target, or technically incorrect.
4. **If there is a fundamental disagreement you cannot resolve alone, ask the user for judgment.** Do not silently override or accept a major pivot.

Update the design document or proposal.

### Round 2: Final review

Send the updated design back:

```
I've updated the plan at <design-doc-path> based on your review. Please do a final review. Flag any remaining concerns, missed edge cases, or issues with the changes. If the plan looks solid, confirm it.
```

Process the response the same way. Ask the user about unresolvable disagreements.

### After design review

1. Summarize what changed and why, including points where you disagreed with Codex and your reasoning.
2. Ask the user for permission to settle the plan.
3. Enter plan mode to write the formal implementation plan.

## Phase 2: Code review (after implementation)

After the implementation is complete (whether committed or uncommitted), prompt the user about a code review:

> "Implementation is complete. Would you like me to send the changes to Codex for a final code review?"

This step is optional — the user may decline if the change is simple or they're confident. But do ask; it's a good checkpoint that catches subtle bugs.

If the user agrees, craft a code review prompt for Codex. Do not use a fixed template — write a prompt tailored to what actually happened during implementation. The prompt should include:

1. **Context**: what was implemented and why (reference the agreed-upon plan).
2. **Change summary**: whether changes are committed (and how many commits) or uncommitted. Summarize what was added, modified, or removed.
3. **Critical files**: list the key files Codex should focus on — the ones with the most logic, the riskiest changes, or the ones most likely to have bugs.
4. **Review criteria**: ask Codex to evaluate correctness/bugs, UX impact, performance, over-engineering, consistency with existing patterns, and edge cases. For each issue found, request severity rating (critical/moderate/minor) and a concrete fix.

After receiving the code review:

1. Assess each finding for validity.
2. Fix critical and valid moderate issues.
3. Dismiss invalid findings with reasoning.
4. For findings where you are unsure or the fix would be a significant change, ask the user.
5. Summarize what was fixed and what was dismissed, with reasoning for each.

## Reference

For detailed tmux scripting patterns, see [references/tmux-patterns.md](references/tmux-patterns.md).

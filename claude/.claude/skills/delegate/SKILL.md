---
name: delegate
description: "Hand implementation of a written spec to a chosen model (codex or claude) in a background session, then review the result."
disable-model-invocation: true
requires:
  - lessons:collaboration/review-lens.md
---

# Delegate — implement a spec with a background session

The economics: your judgment at the ends — the spec before, the review after — and a background session does the labor in the middle. A written spec (or design doc) is the entry ticket: with none, stop and write one first.

## Resolving the voice

Every `--with` names an exact model, resolved from what the user said. A voice they left unspecified takes its provider's default, and a provider they left unnamed is codex.

| The user says | Voice |
|---|---|
| nothing, "codex", "sol" | `codex:gpt-6-sol` |
| "astra" | `codex:gpt-6-astra` |
| "claude", "opus" | `claude:claude-opus-5-5` |
| "fable" | `claude:claude-fable-5-1` |

A model ID the user spells out goes through as written. Effort goes on only when the user asks for one — "sol on high" is `codex:gpt-6-sol:high`, "astra on high" is `codex:gpt-6-astra:high`; unasked, it stays off and the provider's configured level (high) applies.

## Process

1. **Preflight.** Check `git status`: the delegate commits its own work, so a clean baseline is what makes the review diff exact and the work revertible. Dirty tree → ask the user to commit or stash (or to explicitly accept a same-tree dispatch anyway); an invocation that already authorizes it ("commit them") is the answer — commit, then record the baseline with `git rev-parse HEAD`.

   *Worktree opt-in:* when the user wants to keep editing while the delegate runs, `git worktree add <path> -b delegate/<slug>`, pass `--cwd <path>`, and warn that a fresh worktree lacks installed dependencies and env files.

2. **Write the dispatch prompt** — one file, from [PROMPT-TEMPLATE.md](PROMPT-TEMPLATE.md): the spec path, the baseline commit and branch, the project conventions the delegate must follow (test and typecheck commands included), the commit discipline, and the required shape of its **final message — a handoff report**.

   Pitch the whole file to a **senior engineer who hasn't made your journey**: capable, so skip anything they'd already know — but cold, so the hard-won context this conversation paid for (traps, invariants, expensive findings, why the tempting shortcut fails) must be transferred explicitly, here or via the spec's gotchas section. *Transfer context, not competence.* The report shape matters because the final message lands in `result.md` and is exactly what your review consumes; its test-results section makes the delegate account for every test file it touched, so a suite it edited but never ran surfaces in the report instead of in your re-run.

3. **Dispatch** with write intent, anchored to the baseline, 180-minute cap, as one background Bash task, the job named for the round (`delegate-r1`), and return once it is running — the task completing is the signal, and nothing the dispatch prints needs relaying:

   ```sh
   envoy run delegate-r1 --with codex:gpt-6-sol --allow-write --baseline <sha> --prompt-file <prompt> --timeout-min 180
   ```

   The voice is resolved per **Resolving the voice**. A worktree dispatch adds `--cwd <path>`. While it runs, keep discussing anything, but leave the delegate's tree alone — an edit there races it. If the completion notification is lost to a compaction or a restart, `envoy pending` says what still needs attention.

4. **Collect and verify** on the task-completion notification — `envoy collect delegate-r1` prints the handoff report plus the commits and diffstat since the baseline in one block; any other status prints a `next:` line; follow it. Where the report claims tests pass, re-run the project's checks yourself. Done when the report is read, every commit is enumerated, and the checks have been re-run.

5. **Review the diff seriously**, in the review-lens stance (`~/.config/lessons/collaboration/review-lens.md`: step back before judging locally, judge how the change joins the design, the additive-bias bar on tests, over-building flagged) — correctness, spec-fit, structural quality (two questions: are the modules it added or reshaped **deep** — real behavior behind a small interface, not complexity relocated — and did it build on the right **foundation** — reshaping structure that fought the spec instead of piling the feature on top?), consistency with the codebase — starting from the report's where-to-look-hardest.

   Route each finding: mechanical → fix it directly; substantive rework → send the findings into the same session as a fix round, which keeps its write intent — collection's `resume:` command, with a fresh name (`delegate-r2`) and the findings as its prompt file; a direction-level problem → the user decides.

6. **Report** to the user: what was delegated and to whom, diff stats, the review verdict finding by finding (fixed / sent back / dismissed with reason), and the job name, so the session stays continuable.

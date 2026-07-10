---
name: delegate
description: "Hand implementation of a written spec to a chosen model (codex or claude) in a background session, then review the result."
disable-model-invocation: true
---

# Delegate — implement a spec with a background session

The economics: your judgment at the ends — the spec before, the review after — and a background session does the labor in the middle. A written spec (or design doc) is the entry ticket: with none, stop and write one first.

Engine: `node ~/.claude/skills/sidekick-runtime/turn.mjs`. [ENGINE.md](../sidekick-runtime/ENGINE.md) owns lifecycle and recovery: read it before passing a user-supplied `--model`/`--effort` value, after any non-`ok` result, or when a restart/compaction may have hidden a task notification.

## Process

1. **Preflight.** Check `git status`: the delegate commits its own work, so a clean baseline is what makes the review diff exact and the work revertible. Dirty tree → ask the user to commit or stash (or to explicitly accept a same-tree dispatch anyway); an invocation that already authorizes it ("commit them") is the answer — commit, then record the baseline. Record the baseline: `git rev-parse HEAD`.

   *Worktree opt-in:* when the user wants to keep editing while the delegate runs, create `git worktree add <path> -b delegate/<slug>`, pass `--cwd <path>`, and warn that a fresh worktree lacks installed dependencies and env files.

2. **Write the dispatch prompt** — one file, started from [PROMPT-TEMPLATE.md](PROMPT-TEMPLATE.md): the spec path, the baseline commit and branch, the project conventions the delegate must follow (test and typecheck commands included), the commit discipline, and the required shape of its **final message — a handoff report**. Pitch the whole file to a **senior engineer who hasn't made your journey**: capable, so skip anything they'd already know — but cold, so the hard-won context this conversation paid for (traps, invariants, expensive findings, why the tempting shortcut fails) must be transferred explicitly, here or via the spec's gotchas section. Transfer context, not competence. The report shape matters because the final message lands in `result.md` and is exactly what your review consumes; its test-results section makes the delegate account for every test file it touched, so a suite it edited but never ran surfaces in the report instead of in your re-run.

3. **Dispatch** as exactly one Bash `run_in_background` task (builds outrun the 10-minute foreground cap):

   ```
   node ~/.claude/skills/sidekick-runtime/turn.mjs \
     --provider codex --allow-write --baseline <sha> \
     --prompt-file <f> --timeout-min 120 --label delegate
   ```

   `--baseline` is the sha from preflight, recorded in `meta.json` so collection can diff against it. Default is codex with no `--model`/`--effort` flags — the user's codex config governs. Use claude only when the user names it, and pass `--model` only when they name a model — otherwise their claude default runs. Echo whichever model is effective plus the engine's `watch:` / `takeover:` lines from the task output, then return and let the native task-completion notification trigger collection. A takeover is for after the turn finishes. Never substitute a model of your own choosing.

   While it runs: keep discussing anything, but make no code edits in the delegate's tree — you would race it.

4. **Collect and verify** on Claude Code's native task-completion notification: `node ~/.claude/skills/sidekick-runtime/collect.mjs <out-dir>` prints the handoff report plus the commits and diffstat since the baseline in one block. Where the report claims tests pass, re-run the project's checks yourself. Done when the report is read, every commit is enumerated, and the checks have been re-run.

5. **Review the diff seriously** — correctness, spec-fit, test quality (signal, not count: a test that can't fail for a real reason, or that re-proves what an existing one owns, is a defect to remove rather than coverage to keep — and a test you'd ask for must name the bug it catches), consistency with the codebase — starting from the report's where-to-look-hardest. Route each finding: mechanical → fix it directly; substantive rework → send the findings into the **same session** (`--resume <sessionId>`, from the final block or `meta.json`) as a fix round; a direction-level problem → the user decides.

6. **Report** to the user: what was delegated and to whom, diff stats, the review verdict finding by finding (fixed / sent back / dismissed with reason), and the next commands — the resume flag and the takeover command from the final block or `meta.json`.

# Measure the baseline with an interview

Ask fresh subagents what they would do with no instruction, to tell a line
the model needs from a no-op. Use it before writing a line about a default
the model gets wrong, and before keeping or cutting a line that has no eval
case.

## What it can settle

- **Knowledge and stated choices:** a name, a convention, which call it
  would make, what it would write or report. For a doubt about something
  missing from output, ask for a draft from a sample input; an omission
  there counts.
- **Not behavior under task pressure:** stopping early, thin legwork, a
  habit that slips only deep in a long task. Every model says it would
  verify. Settle those with a task run ([improve-tool's `EVALS.md`](../improve-tool/EVALS.md)).
- **Not a line that only saves a round,** such as an inline schema the
  model would otherwise look up. Only a run's cost shows that.

## Run it

1. **Brief two or three fresh subagents** on the model that will read the
   text; mix tiers when it serves several. Tell them to answer from what
   they know, with no tool calls.
2. **Keep the draft out.** Pose each situation in plain task terms, without
   the draft's words, and ask for the concrete action: the exact path,
   command, code, or message.
3. **Write down, before you read any answer,** what answer would mean
   "already does it" for each line. Otherwise the sort bends toward the line
   you hoped to keep.
4. **Follow up** where an answer stays general until it names an action.

## Sort each line

| Answers | Verdict |
|---|---|
| Every subject already does it | A no-op: cut it, unless it guards behavior under task pressure, which stays until a task run settles it |
| Any subject does something else | It earns its place: write the target behavior so it steers them off what they said |

Log each cut in the target's evidence log (`EVIDENCE.md` beside a skill):
what the line guarded, and the sign in later use that would bring it back.

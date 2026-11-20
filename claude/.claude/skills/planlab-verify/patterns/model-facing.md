# Loopy's prompts, tool text and skills

A change to what the model reads is verified by what the model then does, on
the asks planners really send, against the same asks on the baseline.

**It cannot show** a verdict from one run: a model's behaviour varies, so
say how many runs each verdict rests on.

## What the prompts became

```bash
pnpm --filter @planlab/loopy run prompt-lab check                      # shape checks over every composed prompt
pnpm --filter @planlab/loopy run prompt-lab diff --base origin/develop # each rendered prompt, before and after
pnpm --filter @planlab/loopy run prompt-lab why "<words>"              # what puts a sentence in the prompt
pnpm --filter @planlab/loopy run bench:cache                           # the prompt cache's hit rate
```

A diff that changes a prompt the branch did not mean to change is a finding.

## What the model does with it

1. **Take real asks.** Sample what planners actually sent that this change
   touches, from production (`planlab backstage db query`), with each
   thread's id. The planner's words go in as they were, not an instruction
   to use the changed skill: whether the model reaches for it on its own is
   part of the verdict.
2. **Run each on both builds,** the baseline lane and this one
   (`planlab --lane <worktree> --workspace s-<purpose> loopy --single -- "…"`,
   or a case file), more than once when the outcome varies.
3. **Judge blind.** Give two or more fresh subagents each pair of outputs,
   unlabelled and in random order, with what a good answer does for the
   planner; ask which is better and why. Settle a split with a third judge,
   not by deciding yourself.
4. **Report** the sample and how it was drawn, the counts, and two or three
   pairs quoted where the verdict turned.

A skill as installed on production is driven in the sandbox workspace
(`planlab --workspace planlab-dev-qiushi …`), which runs the deployed build,
not this branch.

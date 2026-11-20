# Production

Real data, real configuration, the deployed build. Reads are free; writes
follow `CLAUDE.local.md`: your sandbox workspace `planlab-dev-qiushi` freely
(list them in the report), any other workspace only on the owner's word.

**It cannot show** this branch: production runs the deployed build. To try
the branch on a workspace's real data, read the data here and load it onto
the lane (lane patterns, § Data in). Nor can it show a red for a fix: the
build with the bug is gone once the fix deploys, so the red comes from a
lane baseline.

## Read

```bash
planlab backstage db query --json <<'SQL'      # read-only SQL; 15 s timeout, 1,000 rows by default
SELECT ...
SQL
planlab backstage db describe LoopyRun          # a table's columns before you guess one
planlab backstage loopy evidence <runId> --bundle -o <scratchpad>/<slug>
planlab backstage schedules download_uploaded_raw <schedule-id> -o <file>   # a schedule as uploaded
```

The production logs are CloudWatch Logs Insights through
`aws --profile planlab-prod logs start-query …`.

A schedule with its saved edits comes through the workspace route instead
(lane patterns, § Data in), which needs a workspace token.

## Drive the deployed build

From the repo root. A workspace command needs a workspace token; when none
is configured, the CLI's refusal says how to mint one (`--writable` for
`loopy` and `case run`).

```bash
planlab --workspace planlab-dev-qiushi loopy --single -- "<the planner's words>"
planlab --workspace planlab-dev-qiushi case run packages/loopy-eval/cases/<id>.yaml
planlab --workspace planlab-dev-qiushi case clean <the result dir it printed>
```

`planlab replay <thread>` re-sends a thread on the thread's own workspace,
so replay only threads that live in your sandbox; a customer's thread is
replayed by sending its turns yourself in the sandbox.

## After the merge

```bash
planlab release verify --pr <N>    # read-only: is the merge serving, where
```

A claim only production can settle (fleet volume, organic traffic, a
customer's own data) is a check owed after the deploy: name it in the
report with what it reads and when there is enough to read.

## The remote-workers lab

`qiushi-lab`, beside its in-process twin `qiushi-lab-loopy-in-process`,
runs on the lab's remote hosts. Nobody else sends to it, so an experiment
brings its own traffic: `application/scripts/capacity-drill/lab-drill.ts`
sends lab conversations and follows each to its end (its header gives the
options). Every conversation there is a write, so the owner's word comes
first.

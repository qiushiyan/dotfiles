# The lane: the app and Loopy on this worktree

The lane is this worktree's own app, database and Loopy master, beside every
other worktree's. Commands run from `application/`; `pnpm run lane help`
lists every verb, and `docs/technical/local-dev.md` is the reference. The
first `pnpm run` after a lockfile change installs dependencies before the
verb runs, so its output is not JSON that time: run it once bare, then pipe.

**It cannot show** production's data or configuration, an S3 staging store
(see containers), systemd or real AWS hosts (see aws), the legacy host (the
lane runs the pool), or a connector the lane lacks (a Files drive, a
knowledge base).

## In process, before a lane

A claim about one function, or about Loopy's loop on inputs you give it,
needs no lane: a unit test, a Postgres test
(`pnpm exec dotenv -e .env.development.local -- pnpm exec vitest run --config vitest.pg.config.ts <file>`,
a throwaway database per run), or the loop itself against real Bedrock on a
schedule on disk, `pnpm --filter @planlab/loopy run debug:run -- …` (the
header of `packages/loopy/scripts/debug_loopy_run.ts` gives its options). It cannot
show what the app, the master and its workers add: staging, wakes, a real
model's timing through the pool.

## Up, and current

```bash
pnpm run lane up      # JSON: url, head, session, loopy; started:true means you stop it afterwards
pnpm run -s lane status | jq '{running, head, url: .app.url, restartNeeded, masterRestartNeeded}'
```

The master runs a built bundle: after changing Loopy runtime code, run
`lane up` again. After a migration change, `lane up`; after a dependency or
generated-file change, `lane stop` then `lane up`. The master's warnings:
`pnpm run lane master warnings --since <iso>`, rather than tailing its log.

## Drive Loopy

```bash
pnpm run lane ws new <purpose>      # scratch workspace s-<purpose>, deleted with the worktree
planlab --lane . --workspace s-<purpose> loopy --single -- "<the planner's own words>"
planlab --lane . --workspace s-<purpose> case run ../packages/loopy-eval/cases/<id>.yaml
planlab case clean <the result dir it printed>
```

Read the whole result block: `target` is the build that answered and
`served` the master; a `rig` line is the lane's own trouble, not the
branch's. `finished` says only that the run ended: read what it should have
written.

```bash
planlab --lane . backstage db query --json <<'SQL'
SELECT ... FROM "LoopyRun" WHERE ...
SQL
```

## Data in

- A workspace's real schedule, read from production (no permission
  needed): `planlab --workspace <ws> schedules export <schedule-id> --out <file.xer>`,
  edits included; then upload it as below. Files and rows the claim needs
  come the same way: read them, then load them here.
- The `fixtures` workspace (`/app?ws=fixtures`) already holds the named test
  files (PDFs past each limit, two P6 schedules, a spreadsheet);
  `pnpm run lane fixtures` uploads any that are missing.
- One schedule through the real upload route, as a planner's upload:
  ```bash
  pnpm run lane run -- tsx scripts/local-repro/upload-case-schedules.ts \
    --xer <file.xer> --name "<name>" --workspace s-<purpose>
  ```
  It takes XER only; for another format or file type, write a throwaway
  driver that posts to the same route.
- A throwaway driver against the lane's database and app: put it in
  `application/scripts.local/<name>.ts` (untracked) and run
  `pnpm run lane run -- tsx scripts.local/<name>.ts`, which supplies the
  lane's database, blob directory, `LOOPY_APP_URL` and `PLANLAB_DEV_EMAIL`.
  Import the app's own modules (`@/db`, the service under test) rather than
  reimplementing them.
- The app's own S3 features (workspace public files, email, Files):
  `pnpm run dev:s3-rig -- --port <free port>` serves a minimal S3 on
  loopback; its header says how to point the `GlobalS3Store` row at it. It
  is not a store for Loopy's run staging.

## Red on the baseline, green here

```bash
pnpm run lane baseline [<sha>] --ws <purpose>   # a sibling worktree at the merge-base, its own lane; prints both drive commands
# run the same command on each lane
pnpm run lane baseline rm
```

## Other proofs on a lane

`lane smoke` runs a browser suite on a fresh database and `lane bench`
measures what a Loopy turn costs the main thread (`docs/technical/local-dev.md`).
A Loopy OS change runs the registered stories, `pnpm run pipe-stories --list`,
in both worktrees.

## Tear down

`pnpm run lane baseline rm` for a baseline, and `pnpm run lane stop` when
your `lane up` printed `started: true`. `started: false` means someone else's
app was already running: leave it.

# planlab-verify — evidence log

## Decisions that stand

- **The skill maps rigs; the snippet carries the two fronts.** The target and
  risk paragraph won the 2026-10-13 replays as request text
  (`~/dev/skill-evals/cases/replay-verify`), and moving it into a skill was
  never tested, so `review-verify` and `verify` keep it and the skill holds a
  compact copy for when it is reached without them. Reverse if a replay arm
  with the fronts in the skill alone scores like the request-text arm.
- **Model-invocable, with a "(Planlab)" description.** A pasted snippet
  already counts as a verify step for the PR guard, but a driver's own
  wording ("go on to review and verify") or the guard's refusal reaches only
  a skill that loads on its own. It costs about 25 words in every project's
  listing. Reverse if it fires outside Planlab or crowds out pl-loopy-verify
  on an incident with a dossier.
- **Patterns hold what works today, by domain, outside the body.** Building
  rig tooling is other work (`infra/lane-verify-frictions-ranked` and
  `infra/remote-workers-branch-rig` in the Planlab handoffs); a patterns file
  changes when a tool does, and names what it cannot show.
- **Self-contained for the owner's workflows:** it points at tools (the
  lane, the `planlab` CLI, the AWS kits) and not at the team's QA skills,
  which need an open PR, post to it, or run on production.

## Open comparisons

1. **Undriven claims that a mapped rig reaches.** Predicate: in verification
   reports after 2026-11-20 (sends of `review-verify` or `verify` in Planlab),
   each "not driven" item classified as reachable by a rig the patterns name,
   by a rig that does not exist, or by no rig. Baseline (2026-11-20, 30
   reports, rough): about half were honest limits, and the reachable ones
   clustered on browser checks and S3. Reverse the routing table if the
   reachable share does not fall.
2. **Hand-built rigs.** Sessions that pull IAM credentials from the SSO cache
   (baseline 9 since 10-01) or write their own lane uploader (11): either
   still rising after this skill says what exists means a pattern is wrong
   or unread.

## 2026-11-20 — the skill is born from the review-verify snippet

Session `mini2:5b25b85e` (an `/improve-tool` pass on the user's request, a
consult round with Fable and Carbon, then the build on the user's go). Its
scratchpad held the ledger, the mining results, the consult and the fork
test; not durable.

**Request.** The planlab `loopy-review-verify` snippet bound verification
to pl-loopy-verify, while many branches are infra, UI, search or skills.
Rename it `review-verify`, shadowing the global key, let the session choose
the rig, and give it pointers to the stacks that exist; encapsulate patterns
sessions keep rebuilding.

**Corpus.** Obelisk, mini2 and mini (the mac timed out on the wide query),
2026-10-14 → 11-20. Sends: user text holding `verify this branch with
pl-loopy-verify`, 30 sessions' windows (14 sent by the driver as a file; the
consult found two more driver sends typed as a slash command). Window: the
send to the next typed turn. Wide counts over all Planlab sessions since
10-01 (about 1,650): `LIKE` matches over tool input, upper bounds. Ledger and
raw JSON in the session's scratchpad (`ledger.md`).

**Findings.**
- Sessions already left the lane under the old wording (agent-browser 7 of
  30, Docker 4, AWS about 9), so the binding cost less than its name
  suggested; the larger costs were facts with no home and tools nobody
  found: `pnpm run dev:s3-rig`, `scripts/local-repro/upload-case-schedules.ts`,
  the fixtures workspace, `infra/loopy-smoke/`.
- "Not driven" lists stop at the lane's edge (real S3, EC2 and systemd, the
  real Lambda, a chat card in a browser), and about half are honest limits
  no rig reaches. The largest cluster is remote workers, which have no rig
  before the merge.
- Rebuilt by hand: IAM credentials for the personal account dug out of the
  SSO cache, 9 sessions (the profile had PowerUserAccess only); a lane
  uploader, 11; a local S3, about 4–5 looked and 1 built (the first count,
  8+, was mostly digest bots and greps: the consult caught it).
- Contradiction found on the way: the driver's notice and `PLANLAB.md` let
  sessions write to demo and internal workspaces unasked; `CLAUDE.local.md`
  allowed only the sandbox.

**Consult** (`consult-r1`, Fable and Carbon, one round). Both sharpened the
problem as above. Adopted: fronts stay in the snippet; old worktrees would
silently resolve `review-verify` to the global spike snippet, so both keys
live in the main checkout's `.tabtype.local.toml`, which wins in every
worktree; rigs by kind with what each cannot show; existing tools before
recipes; AWS by profile, tags and teardown; per-branch names for shared
rigs; commit before the review; verification fixes drive again and count
toward the review's second round. Split, decided by the user: invocable
(Carbon) over path-only (Fable).

**Changed.**
- New: this skill, `SKILL.md` and `patterns/` (lane, browser, containers,
  aws, production, model-facing).
- Planlab snippets: `review-verify` and `verify` in the main checkout's
  `.tabtype.local.toml`; the same keys, with `review-then-closeout`,
  `consult-then-build` and `loopy-batch-review` pointing here, committed on
  branch `tooling/review-verify` (not pushed).
- PR guard (`claude/.claude/hooks/pr-stage-check.py`): keys `review-verify`
  and `planlab-verify`, the review named as `full review`; its test.
  Session board: `planlab-verify` and `spike` under verify, the new keys
  beside the old ones.
- Review and consult: fable is the voice when none is named.
- Workspace writes (user's word): the sandbox freely, listed in the report;
  any other workspace on the owner's word: `CLAUDE.local.md` (both copies),
  `codex/.codex/AGENTS.md`, the driver's `NOTICE.md` and `PLANLAB.md`.
- `~/.aws/config`: profile `planlab-personal-deploy` (DeploymentCreator in
  the personal account), checked with `sts get-caller-identity`.
- Handoffs: `infra/remote-workers-branch-rig`, `infra/lane-verify-frictions-ranked`.
- Left for the docs pass: `docs/session-pipeline.md` (stage 5, project
  snippets, spikes, § Who decides on workspace writes), `docs/planlab.md`,
  `tabtype/DESIGN.md`.

**A fresh reader** (revise-prompt's pass, two scenarios: a GNU-parity
sandbox change, a driven fix that shows only on demo data) found eight
faults, all fixed: no route for a fix that shows only on real data
(production runs the deployed build; now: export the data, load it onto the
lane), GNU answers from the wrong image (the repo's corpus image and its
test), the review default contradicting the other-family rule, no
in-process rig, `infra/app-tier-rig` having no README, the hook's file
path, a pre-build spike counting as verification on the board (`spike`
left out of the verify label; `consult-then-build` points at the patterns
folder, not the skill), and unchecked brief claims. Checking one brief claim
falsified it: `infra/loopy-smoke/` already builds a remote worker box
(`RIG_REMOTE_WORKERS`), so the remote-workers brief now asks why it went
unused and whether only an Auto Scaling group is missing.

**Fork test** (`forks/` in the session scratchpad). Five sessions cut at
their `loopy-review-verify` send (#11706, #11413, #11437, #10969, #11167),
resumed with `--fork-session`, Opus 5.5 at 1M, Read/Grep/Glob/Skill only,
one run per arm, each asked for a dry-run plan; old prompt without the
skill installed, new prompt with it. Judged blind by Fable and Astra
against each PR. New won 9 of 10 verdicts (4 clearly, 5 slightly); old won
one, slightly (Fable on #11437). Invented or wrong commands: old 51, new 55
(the two judges' counts summed): no gain, though a plan written without a
shell is where a real session would run `--help` first. Reachable claims
left undriven: old 113, new 106. Judges credited the new plans with the
right rig (the AWS kit and a container for #10969) and with naming what was
not driven. Limits: the #11706 new arm never opened the skill (its win is
not the skill's); #10969's read the files directly; no old arm opened
pl-loopy-verify; the merged branches' worktrees are gone, so plans lean on
memory; the forks ran while the fresh reader's fixes landed, so some read
the earlier text; the judge brief named `~/.claude/skills` as a guide to
what rigs exist; and old was plan A in 4 of 5. Directional, n of one per arm.

**Verified.** The PR guard suite, 173 of 173, after each change. `drive
snippets` resolves `review-verify` to the new text in an old worktree, in
the new branch's worktree, and to the global key in dotfiles. `brief check`
clean on both briefs. `skill-sync --check` clean. The new AWS profile
answers `sts get-caller-identity` as DeploymentCreator.

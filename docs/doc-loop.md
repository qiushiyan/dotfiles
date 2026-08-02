# The doc loop — onboarding → work → handoff

How durable knowledge crosses coding-agent sessions: **the project's docs are the memory; each session deserializes them at start (onboarding) and serializes what it learned at end (update-docs / handoff)**. Sessions are ephemeral; a fresh session with a distilled artifact beats a long session with `/compact`. All checkpoints are user-triggered by design — the skills never fire themselves.

## The loop

```
/onboarding <topic>          ← first prompt: spine reads + topic-scoped deep dive
  → the session's actual work
/update-docs                 ← docs reconciled with the diff (may run mid-session too)
/handoff [next: …]           ← lessons + a baton in ~/dev/.handoffs, itself the next first prompt
  → new worktree, pbcopy < the baton, paste — line 1 fires /onboarding <topic>
```

`/update-docs` and `/handoff` are separable on purpose: a routine change wants a doc pass with no handoff; a mid-task stop wants a handoff with the doc pass deferred. `/handoff` *contains* the doc pass (it defers to the project's update-docs skill) — never the reverse.

## The commands, by project

| Project | Onboard | Wrap up |
|---|---|---|
| duet | `/onboarding [harness \| providers \| prompts \| surface \| design]` | project `/update-docs`, global `/handoff` |
| itell (`apps/platform`) | `/onboarding [topic]` | project `/update-docs`, global `/handoff` |
| planlab — Loopy agent/triage | `/pl-loopy-onboarding [agent \| triage]` | `/pl-loopy-update-docs` |
| planlab — infra migration | `/pl-loopy-infra-onboarding [topic]` | `/pl-loopy-infra-handoff` (rich four-phase variant; global `/handoff` defers to it) |
| anywhere else | read the docs tree by hand | global `/update-docs`, global `/handoff` |

Global skills live in `claude/.claude/skills/{update-docs,handoff}/` (this repo); project skills in each repo's `.claude/skills/`. Both globals defer to a project's own skill or `documentation-standards.md` when present.

## The handoff (`/handoff`, `~/dev/.handoffs`)

- **Gate first.** Thread continues → full handoff. Stopped mid-task → baton now, doc pass becomes the next session's first move. Work done and nothing queued → doc pass only, and the spent baton that spawned this session gets deleted — a manufactured or stale baton is worse than none. Pass the answer inline to skip the question: `/handoff next: wire the retry path`.
- **The artifact is `~/dev/.handoffs/<repo>/<slug>.md`** (central, outside every worktree; sibling of `~/dev/.worktrees`), addressed to the next session's agent: state, lessons and dead-ends with their *why*, first moves (reads, claims to verify, a no-code-first synthesis gate).
- **The slug is the *next* session's branch, not this one's.** Today's branch is merged or nearly so, so naming the baton after it files it under work that's already over — and leaves the next worktree's name to be looked up. Naming it forward makes the filename the argument to `gwt <slug>`: one token for the baton, the branch, and the worktree. It also closes the lifecycle — the baton that spawned the session you're in is named for the branch you're on, so deleting a spent one is a lookup rather than a hunt. Review posture has no next worktree, so its slug is `review-<branch>`, and cleanup checks both names.
- **The project folder is computed, not prompted** — `claude/.claude/skills/handoff/handoff-path.sh <slug>` prints the baton path and creates its folder, so the skill carries no derivation to re-run and no repo-layout examples to rot. `<repo>` is the checkout's path under `~/dev` with `/` flattened to `-` (`headroom`, `dotfiles`, `planlab-main`, `marswave-cola`). Which git query names the checkout depends on its kind, and the two disagree by design: an ordinary checkout — a submodule included — is named by `--show-toplevel`, while a linked worktree is named by `--git-common-dir`, since each query returns git's plumbing for the other. Flattening isn't injective (`a/b-c` and `a-b/c` both give `a-b-c`); what it buys is that the *realistic* collision goes away — every `<project>/main` checkout sharing one `main/` folder — without a special-case list. Escaping hyphens to make it reversible would cost every ordinary name its readability, so the rare pathological pair is accepted. `handoff-path.test.sh` pins all of this. `pl-loopy-handoff` is team-shared so it can't call the helper; being single-repo it hardcodes `planlab-main` instead.
- **It *is* the next first prompt, not a document about the work.** The flow is: new worktree → `pbcopy <` the baton → paste. Line 1 is therefore the `/onboarding <topic>` invocation with no title above it; paths stay repo-relative to survive the worktree switch; the text calls itself "this brief" and never tells the agent to read a file — the paste is the delivery. Onboarding skills stay neutral — they never auto-read it.
- **Lives outside git entirely** — the central folder needs no ignore rules, and its per-project folders double as the archive (`ls -lt` orders them; the date lives in the baton's body, not its name). Projects with linear roadmaps may still archive copies in their records dir.
- **Honesty floor:** a session that taught nothing transferable hands off state + next move and nothing else.

## The doc shape that keeps onboarding cheap

Onboarding cost is doc-tree shape, not skill wording. The contract (encoded in each project's `documentation-standards.md` and enforced by its update-docs verify step):

- **Spine / satellites.** The always-read Phase-1 set carries the mental model — principles, vocabulary, workflows, invariants; mechanism lives in topic satellites that onboarding Phase 2 routes to. A spine section that grows past its mental model is a split waiting to happen.
- **Budget: ~100KB (`wc -c`) for the Phase-1 set** (~25k tokens ≈ well under 10% of the window after overhead). The update-docs skill's verify step measures it and must flag an overrun, naming the split candidate, even when the split is deferred. Exceeding is allowed only as a recorded decision — never drift.
- **Reference implementation: duet** (2026-07): `automation-design.md` 141KB → 68KB spine + `run-operations.md`, `afk-resilience.md`, `consultant.md`, `voices-and-providers.md`; Phase-1 set 234KB → 161KB; `engineering.md` (66KB) is the flagged next split. itell already has the shape. planlab's agents tree ports next; the firecracker docs get the treatment at the migration's natural distillation point, not mid-flight.

## The periodic pass — `/distill-docs`

Update-docs is diff-scoped, so cross-doc duplication and rot in untouched files accumulate in the seams no matter how disciplined the per-change passes are (duet accumulated three copies of one key list and two shipped specs across 17 update-docs runs). Roughly monthly — or when update-docs' budget check flags an overrun — run the global `/distill-docs`: mechanical sweeps + a delegated redundancy map → owner-confirmed surgery → verify → a *fix-the-generator* step that patches the project's standards or update-docs skill when a rot class recurs. It defers to each project's `documentation-standards.md`, including its protected exceptions. duet's 2026-07 spine/satellite surgery is the manual prototype it encodes.

## Principles

- **Docs lead, code follows; sessions evaporate.** Anything worth keeping lands in the docs (durable, shared) or the handoff (session-to-session bridge) — never only in a transcript.
- **Every edit nets tighter.** Adding content is the moment to cut; deletion is maintenance; spotlight the load-bearing, let the code hold the inventory.
- **Point, don't pre-chew.** Onboarding and handoffs hand the next session pointers and claims-to-verify, not answers — verification is what makes the knowledge its own.
- **Wrap up at task boundaries, not context exhaustion.** Past ~50% window, write the baton first (it needs the session's memory) and run the doc pass fresh (it only needs the diff).

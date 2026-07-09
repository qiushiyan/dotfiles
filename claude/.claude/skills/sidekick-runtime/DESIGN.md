# Design philosophy — /consult, /delegate & /review

The skill bodies say what to do; this file records **why** — the assumptions, mental models, and rejected alternatives a future redesign needs but can't see in the skills themselves. It is deliberately not linked from any SKILL.md: runtime agents never need it, so it costs them nothing. Read it when revisiting the design; update the evidence log when usage teaches something new.

## Origin and the governing lesson

/consult and /delegate distill `/pair-coding` (a tmux-pane cross-reviewer) after two sessions of screen-scraping friction: completion watchers false-positived on the input prompt, readiness timed out against splash screens, a Codex self-update ate 4.5 minutes, the user had to hand-type "seems codex finished". The lesson that governs everything here: **a screen is not an API**. Sessions are driven headless and read back as data — JSON envelopes and event streams — never `capture-pane`.

## Division of labor

Three layers, each owning exactly one thing:

- **The engine (`turn.mjs`)** is deterministic mechanism: one turn in, files out (`result.md` is the return value, `meta.json` the coordinates). It holds zero judgment — no retries, no review loops, no gates. It is not a job manager (Bash `run_in_background` is) and not a sandbox (write intent is a flag; read-only is a prompt convention).
- **The skills** are judgment procedures for the host: when to dispatch, what the prompt must contain, how to collect, verify, and route what comes back.
- **The prompt files** (brief / dispatch prompt) carry all task-specific intelligence. Templates hold the invariant scaffold so per-run authoring is only the judgment slots.

**Fold-back trigger:** if the engine ever wants review loops, gates, or unattended-resilience machinery, it has outgrown a personal skill — reach for duet instead. Don't grow the engine.

## Shared commitments

- **Human at every boundary.** Dispatch, collection, round-2, verdicts — a person (or the host acting in front of one) sits between every stage. That's why the engine can stay judgment-free.
- **No model substitution, ever.** No `--model`/`--effort` → the provider's own config governs. The host never picks a model the user didn't name (a Sonnet default was proposed at authoring and retracted on user correction). The effective model is always echoed so nothing is silent.
- **Independence picks the default provider.** The host is usually Claude Code, so a codex sidekick buys cross-family review for free; both providers bill a flat subscription, so cost isn't the tiebreaker. Default codex; claude is opt-in by name. (`--max-budget-usd` stays claude-only, kept for future.)
- **Background is the default posture**; collection is notification-driven. Polling a background task is a smell — the one acceptable read is grabbing the coordinate lines right after dispatch.
- **Durable artifacts over stdout.** Files are authoritative; stdout is a convenience view of them.
- **Native provider vocabulary only.** Effort values are never alias-translated, and validated pre-spawn because the providers fail differently (claude silently degrades; codex burns a turn-start on a 400).

## /consult — independent second opinions

- The host is the **lead**; voices are peers, not authorities. The product is the host's synthesis — adopt what survives scrutiny, rebut with reasons, present unresolvable forks to the user. Silently deferring to the voice and silently overriding it are equal failures.
- **Independence is the payload.** Every voice gets the same brief and never another voice's output. Cross-family diversity (codex voice vs claude host) is deliberate.
- Two modes with opposite information hygiene, one shared failure model (*the voice anchored on what it should have judged*):
  - **Design mode** — the host's proposal is withheld; an anchored voice critiques instead of designing.
  - **Review mode** — the artifact is handed over, but settled direction is fenced off ("decided, not up for relitigation") with an evidence-gated escape hatch for foundational objections; an unfenced voice relitigates instead of executing.
- **Round 2 resumes the same session** (fresh would restart from zero). It's optional — handing the user the takeover command is the cheap substitute, and real usage chose that.

## /delegate — implement a written spec

- **The spec is the entry ticket and is out of scope.** The skill assumes a good spec already exists (written with whatever process — usually a full spec/review arc) and refuses to run without one. Delegation quality is mostly spec quality; the skill can't fix a bad spec and doesn't try.
- **The audience model: a senior engineer who hasn't made the journey.** Capability is assumed — no babysitting, no how-to — but the exploration behind the spec is not, so the dispatch prompt's real cargo is the hard-won context the conversation paid for (traps, invariants, expensive findings, why the tempting shortcut fails). *Transfer context, not competence.* This started as a follow-up instruction the user supplied on most invocations; baked into the skill and template 2026-07-06 so it no longer needs restating.
- The dispatch prompt owns exactly two things, and nothing the spec owns: **task instructions** (baseline, commit discipline, conventions, checks, report shape) and **onboarding/orientation** (the reading list, the key files, the hard-won context). WHAT lives in the spec; HOW lives in the prompt.
- **Clean baseline is the load-bearing invariant** — it makes the review diff exact and the work revertible. Same-tree dispatch + host-freezes-its-hands is the default; worktree is opt-in (auto-worktree was Codex's recommendation at authoring, rejected for dependency/env cost).
- **The handoff report is shaped by the review that consumes it** (the same principle as tabtype's `implementation-handoff`): each section pre-loads an evaluation axis; where-to-look-hardest points but never self-grades. Test results must account for every test file *touched*, not just suites run — a delegate once edited five sibling test rigs without running them, and only the host's re-run caught it.
- **Trust but verify:** the host re-runs the project's checks itself, always. Findings route by weight — mechanical → fix in host; substantive → fix round into the same session; direction-level → the user.

## /review — independent review of committed work

- **The mirror of /delegate, and the invariant both serve:** whoever wrote the code never gets to be its only reviewer. /delegate points the host at a delegate's commits; /review points a fresh voice at the host's (or the user's) own.
- **The brief is the user's proven `review-implementation` tabtype snippet made cold-startable.** The warm duet reviewer already held the spec, plan, and range in context; the brief must carry them explicitly — authority paths, a settled-decisions fence (consult review mode's fence, same evidence-gated escape hatch), the commit range, a do-not-flag list. Industry echo (Cloudflare, 131k+ review runs): "what not to flag" is where prompt value concentrates, and evidence-gating (cite code or don't report) is the strongest false-positive filter.
- **Report by provenance.** The reviewer's map comes from wherever the work came from: delegate → its handoff report verbatim; host-built → written fresh in the handoff shape (guided map, never self-graded); user-built → reconstructed from commits and labeled as such. Same tabtype principle — a report is shaped by the review that consumes it — and always a starting point, never the boundary.
- **Judge pass before any fix.** Findings hallucinate with full confidence; the host re-verifies each against the code (Cloudflare's coordinator does the same and drops what fails). The host's conflict of interest is named in the skill because it cuts both ways: agreeable adoption and defensive rebuttal are equal failures — the same both-ways symmetry as consult's "silently defer / silently override".
- **Strategic-over-tactical posture leads the brief.** User observation from manual rounds: reviewers' default failure is optimizing inside the implementation's frame — a local optimum — instead of stepping back to the reshape (a new module, a shared extraction, different wiring). The posture section opens the brief with Ousterhout's strategic/tactical vocabulary (native here — codebase-design is Ousterhout-based); the structural-quality bullets remain the concrete checklist; the fix step forbids shrinking a confirmed structural finding into a local patch. The fence bounds it: shape of the code, never settled product decisions.
- **Cross-family default is independence, not just economics.** A codex reviewer on claude-host code reviews across model families; same-session self-review mostly produces agreement.
- **Round 2 resumes the same session** and asks only "integrated or hand-waved?" — the `review-implementation-again` posture. Optional, like consult's: the takeover command is the cheap substitute.
- **No agreement-weighting across multiple reviewers** (industry does this to cut noise) — consult's independence rules apply unchanged, and the host's judge pass already is the aggregator.

## Deliberately not built

- No job store, no status/cancel subcommands, no `sidekick ls` — Bash background tasks + job dirs already are that.
- No sandbox flag for codex, ever — `~/.codex/config.toml` governs (a derived read-only sandbox broke the session's own tooling; duet, 2026-06-22).
- No prompt-templating engine — templates are markdown files the host edits with judgment.
- No effort aliases, no model fallbacks, no automatic provider selection.

## Evidence log

- **2026-07-03 — authored** (from `/pair-coding` postmortem + a live codex consult on the design). Smoke-tested: ok paths, resume continuity, validation rails, out-dir self-ignore.
- **2026-07-04..06 — first six invocations** (1 consult, 3 delegates + 1 fix round, 1 meta-question). All dispatches `ok`; reviews were substantive every time (real findings each run; one bug the delegate missed, one architecture-level fix round). Frictions found: the session id / watch command was never proactively surfaced (user had to ask); the blind-brief rule didn't fit review-mode consults; collection was ~5 hand-typed steps; `meta.json` was prescribed but stdout was what hosts actually used; a delegate's test edits went unexercised and unreported.
- **2026-07-06 — improvement pass** (transcript-driven): review/design modes split in consult; watch/takeover echoed at dispatch; `collect.mjs`; `--baseline` recorded in meta; early `meta.json` (crash-safe coordinates); full token capture (codex input is mostly cache — record the split); session lock against racing a live turn; brief/prompt templates; report gains test-file accounting. Smoke tests of the previously-untested paths found and fixed a real hang: a timed-out provider with grandchildren holding stdio pipes never fired `close` — `exit` + grace period is the fallback.
- **2026-07-08 — /review authored** (from the user's manual `review-implementation` tabtype snippet + a web survey of production AI-review systems). Same-day posture pass: the brief now leads with the strategic step-back after the user flagged local-fix bias as the top reviewer failure. Untested at authoring; first invocations should confirm the report-by-provenance step, the judge pass, and the posture section earn their keep.

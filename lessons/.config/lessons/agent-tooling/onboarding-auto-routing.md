# Migrating onboarding to problem-driven routing

Use this guide when redesigning an onboarding skill so an agent can select the knowledge a supplied problem needs. The intended result is a grounded analysis or proposal from one invocation, with enough product and domain context to preserve the project's design. The migration changes who selects the reading; whether the skill itself is invoked automatically is a separate choice.

This guide is for the agent or maintainer designing that migration. The resulting onboarding skill speaks to the agent investigating the problem. The [prompt-engineering rulebook](../../../../claude/.claude/skills/prompt-engineering/SKILL.md) owns general writing guidance; this document carries the migration decisions, failure cases, and validation lessons from the platform experiment.

## Design the reader's task

**Start from the executing agent's situation.** It has received a problem, perhaps with an issue reference or a handoff. Its job is to establish what is happening, learn the contracts that matter, and recommend a solution. Before drafting, describe that starting state and what would count as a useful completed turn. Use those answers to judge the instructions; they need not become extra output sections in the skill.

The distinction is visible in an opening sentence. These are illustrative formulations, not a transcript:

<example type="avoid">
The user can provide free-form context instead of selecting a route, so onboarding no longer needs a topic-selection message first.
</example>

<example>
Understand the problem, gather the project and domain knowledge needed to investigate its cause, and propose a clean solution.
</example>

The first explains the requested invocation convenience. The second gives the investigator a goal. A sentence about accepted input earns space when it resolves an actual ambiguity, such as which repository a bare issue number names. Product rationale earns space when it shapes a judgment. The history of why the human wanted automation belongs in migration evidence.

**Define what the agent must judge.** A goal alone leaves the important choices implicit. The skill needs criteria for relevance, sufficient understanding, competing explanations, unresolved uncertainty, and completion. These criteria let the model choose its method. Ordered steps belong where sequence changes correctness, such as checking a handoff's drift before trusting its claims.

Set the first-turn boundary explicitly. Platform onboarding ends with analysis or a proposal even when the supplied issue says “fix” or “add”; implementation follows the user's response. For another project, settle that contract before changing routing. Automatic selection does not itself authorize implementation or change a downstream gate.

## Make the reading structure support selection

**Separate universally needed orientation from conditional domain contracts.** The shared foundation explains the project, its audience, intended outcomes, and governing vocabulary or invariants. A detailed document earns universal status only if arbitrary tasks need it to avoid a wrong diagnosis or misaligned proposal. Familiarity with a subsystem is insufficient justification.

Platform uses its already-loaded CLAUDE.md and PRODUCT.md's Users and Product Purpose sections. Detailed tenancy, cohort, and action contracts are reached when the problem needs them. Another project must derive its foundation from its own risks; platform's files and byte budget are calibration data, not a template.

Give each layer one responsibility:

| Layer | Decision it supports |
| --- | --- |
| Main skill | What to establish, when further reading matters, and what ends the turn |
| Route descriptions | Which domains may explain the problem |
| Route files | Which questions the domain documents answer, including conditional crossings |
| Domain documents | The authoritative model, constraints, mechanisms, and rationale |
| Pickup gate | The handoff's required ordering, evidence standard, and response contract |
| Maintenance guidance | How to keep those pointers and responsibilities valid |
| Evidence record | Why the migration changed and what has actually been verified |

**Select within a route as well as between routes.** Replacing human selection with a model while keeping a mandatory reading package preserves much of the original cost. A content route can cover CMS fetching, generation, import, and rendering without requiring all of them for a fetching problem. Analytics should reach admin preview tools only when preview behavior matters.

A useful pointer joins a recognizable question to a source and sufficient surrounding context. Start with the selected domain's model and constraints, then the relevant sections; read a whole document when its argument or contract spans them. Section-level selection depends on document structure: a heading mixing unrelated mechanisms may need a documentation refactor. Making the router say “read less” cannot repair an unaddressable source.

**Let evidence revise the route.** The initial symptom gives a starting point. Read another domain when a dependency, competing cause, or proposed change raises a question that could change the conclusion. Shared code can require another surface's contract even if the user named only one surface. A fixed route count or a rule against secondary domains can exclude the actual cause.

Use a sufficiency condition the agent can evaluate: it can explain the affected mechanism, identify the constraints a solution must preserve, and state the uncertainty that could change its recommendation. A proposal reopening a recorded decision also needs the decision's rationale. Stop expanding when the next read would not inform one of those judgments. Fewer reads are useful only while those obligations remain satisfied.

## Migrate the surrounding workflow

**Follow the consumers of the old contract.** Search the project and shared workflow for invocations, topic-first examples, “already read” assumptions, fixed reading sets, maintenance rules, handoff writers, and saved memories. Inspect each hit for its role. A caller that still asks for a route and a second task message can preserve the manual workflow after the skill changes.

Keep issue resolution and gate precedence explicit where they affect behavior. A linked issue supplies reported facts and a suggested approach whose current validity still needs checking. A pickup supplies historical claims whose ordering is governed by its gate. Resolving every reference immediately can read the brief before the gate permits it. Put that exception at intake; a late caveat cannot reliably undo an earlier read.

Update section references when headings move or change, and include route files in documentation reference checks. Store current instructions in their owning layer. Keep review history and old measurements in evidence, labeled as historical; a retrieved memory must identify the current contract.

## Traps exposed by the platform refactor

The guard column is what a future migration should check. The evidence distinguishes defects found in the drafts from risks examined in scenarios; runtime failure frequency was not measured in this pass.

| Trap | What the platform pass showed | Guard |
| --- | --- | --- |
| Describing the requested automation | The user rejected intake language that described the requested automation | Read the opening with a real problem already supplied; identify the investigator's task and completion condition |
| Adding goal language without judgment criteria | The first rewrite named the outcome while retaining broad reading obligations | Find the rules that decide relevance, expansion, and sufficient understanding |
| Keeping mandatory route spines | Content required CMS reads plus generation; dashboard required analytics plus preview tools | Trace one narrow question through every required read and justify each dependency |
| Treating familiar domain detail as project-wide core | Organization, cohort, and action detail stayed universal until the broader redesign | Justify each shared read against unrelated representative tasks |
| Treating a symptom or issue's proposed fix as the cause | A risk checked in issue and cross-domain scenarios, rather than an observed misdiagnosis | Identify the source evidence or competing explanation that would change the route or proposal |
| Scattering clarification and pickup exceptions | Opus found conflicting intake/pickup ordering and scattered clarification rules | Give each decision one home; place sequencing exceptions before the action they constrain |
| Copying domain invariants into route files | An inline access-flag claim was ambiguous without the progression-mode contract | Point at the governing contract and verify that the selected section contains the constraint |
| Missing callers, memories, and heading maintenance | A cross-repo caller and memory retained old guidance; heading changes lacked a maintenance trigger | Search consumers and check section pointers as well as paths |
| Calling smaller text a successful migration | Static shrinkage was measured; real-session improvement remained unmeasured | Report static size, scenario behavior, and real-session outcomes separately |

## Validate decisions, not just destinations

**A reader finding a plausible route proves only routing interpretability.** An initial platform check confirmed that readers could reach an analysis-only response; it did not expose how much unrelated knowledge mandatory reads consumed. A migration check must observe what was read and what knowledge shaped the conclusion.

Use fresh readers with concrete inputs and no migration rationale. Ask them to report the reads actually made, constraints learned, first unsupported assumption, remaining uncertainty, and where they would stop. Keep those evaluation records outside the skill's normal response contract. Useful cases include:

- A narrow problem inside a broad route, to detect mandatory unrelated reads.
- A symptom whose explanation crosses domains, to detect premature narrowing.
- A shared component on a different surface, to preserve both surfaces' contracts.
- An issue reference carrying a stale or unproven proposed fix.
- A “fix/add” request, an ambiguous problem, and a topic without a problem, to check the first-turn boundary and useful clarification.
- An incident identifier, a completed diagnostic dossier, and unavailable or inconclusive diagnostic evidence, where that workflow exists; check that evidence determines routing and that uncertainty survives.
- A real pickup pointer, to check gate, drift, brief, and response ordering together.

For each concrete case, identify at least one governing constraint and one plausible unnecessary read before judging the result. Check what the reader actually used. A short answer or an agreeable review is insufficient evidence that the model preserved the domain model. Do not demand a fixed reading list when a different path supports the same sound conclusion.

Report three kinds of evidence separately:

| Evidence | What it establishes |
| --- | --- |
| Links, heading checks, metadata, required bytes | Structural validity and the cost explicitly required by the documents |
| Read-only scenario runs | How those readers interpreted instructions and selected context for those cases |
| Comparable real sessions | Whether useful proposals retain domain constraints while reducing irrelevant reads, repeated-task questions, and scope violations |

Platform measured the shared foundation at 57,430 → 10,100 bytes and the final main skill, pickup reference, and routes at 20,504 bytes. Scenario readers retained relevant constraints across CMS reads, analytics, invitations, public typography, SCORM reporting, and simulated pickup ordering. Opus verified the major fixes and caught remaining ADR and maintenance issues. These results do not establish runtime token savings or improved proposal quality; the pickup simulation did not exercise a real brief.

## Apply the lessons to PlanLab

**Carry the judgment rules across; derive the workflow locally.** Inspect the current Loopy skill, route documents, evidence-producing tools, and pickup consumers before choosing a replacement contract.

The inspected `pl-loopy-onboarding` sends concrete incidents to `pl-loopy-debug` first, so the resulting dossier can name the domain. Preserve or explicitly redesign that evidence boundary: asking an onboarding router to guess from an incident ID could undo it. General problem descriptions, design questions, and dossier-backed investigations may reach domain knowledge at different times.

Loopy also distinguishes its loop, run hosts, tools, triage, evaluation, and surface behavior. Derive shared context and conditional crossings from those dependencies, including current and legacy behavior. Route count alone says nothing about the appropriate read budget.

Audit pickup ordering against the actual shared gate before porting platform's adapter. At inspection, Loopy's skill described reading the brief and drift before reading the gate; the shared gates require drift before post-onboarding reads. That difference needs reconciliation in the migration, not preservation by copying either sequence unexamined. PlanLab was not changed or end-to-end evaluated by this experiment.

## What this says about the writing rulebook

**Reading a rule is not evidence that the artifact follows it.** The existing rulebook already required the model's goal, judgment-shaping constraints, conditional context, one home per behavior, and a cold revision pass. The first platform draft failed to apply those rules. This is evidence of an execution failure, not evidence that the principles were absent.

A narrower guidance gap was that “the reader is the model” still leaves two possible readers in a skill-refactoring session: the model designing the skill and the model later executing it. The rulebook's revision pass tests instructions with a concrete input already in the executor's hands and asks which next action or judgment each sentence changes. The opening example in this guide makes that distinction inspectable. Whether the added check prevents recurrence remains unmeasured.

For future reflection, tie each correction to a failing artifact, identify its owning layer, and choose the smallest change that makes the failure observable on a fresh case. When a rule already exists, improve its application check or example before adding more doctrine. Preserve counterexamples and limits: an unclear user outcome can still require a question, a cross-domain problem can still require substantial reading, and an intentional analysis boundary can still warrant a deliberate echo.

## Evidence and ownership

The source record is the `learlab/itell` repository, `apps/platform/.claude/skills/onboarding/EVIDENCE.md`, entries dated 2026-09-11. The first rewrite is `49ef2884`; the sufficient-context redesign is `0c3a4e62`; follow-up fixes are `1a1cc2a4`. Those entries carry invocation receipts, review dispositions, scenario limits, and deferred diagnostic work. The controlling corrections and approval are in Codex session `01a08fae-2a4e-7cf2-948b-47ef172ad679`.

PlanLab observations are from its `.claude/skills/pl-loopy-onboarding/SKILL.md`. Shared pickup gates live under `claude/.claude/skills/handoff/pickup/` in dotfiles; `docs/doc-loop.md` owns the pipeline. Recheck those current sources during a migration. Keep new project-specific results in that project's evidence record; amend this guide only when they change a transferable decision or expose a new trap.

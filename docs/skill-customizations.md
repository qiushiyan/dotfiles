# Maintaining customized skills

This is the decision guide for updating skills we have adapted from upstream.
Read the relevant entry before changing a customized skill. A successful
update brings useful upstream improvements into our workflow while preserving
the reasons the customization exists.

## What each document owns

- **This document:** the purpose of each customization, its preservation
  constraints, and the judgment to apply when upstream changes.
- **The skill's `SKILL.md`:** instructions for doing the work today. Keep
  maintenance history out of the execution path.
- **`.upstream/PINNED.txt`:** source, reviewed revision, and the procedure for
  checking or restoring the baseline. Private source contents stay gitignored.
- **`LESSONS.md`:** evidence behind local choices and the verdicts from update
  reviews. A past workaround is a hypothesis to recheck when its cause changes.

[Agent skills](agent-skills.md) owns installation, sharing, and ownership tiers.
Customized bodies stay outside the CLI lockfile; otherwise an automatic update
can overwrite them.

## How to judge an upstream change

Compare the new upstream with the pinned upstream first. Comparing it only
with our body mixes new upstream work with deliberate local differences.
Then classify the delta against the relevant purpose below:

- **Adopt** corrections or capabilities that help the intended workflow and
  are supported by the installed tool. Rewrite them in the local skill's
  structure, with examples where those make the workflow reliable.
- **Defer** changes that depend on unavailable runtime behavior or unresolved
  evidence. Record what would make them applicable.
- **Leave upstream** host-specific or general-purpose material outside our
  intended workflow, and changes already covered by local guidance.
- **Retire a customization** when its original problem is demonstrably fixed.
  Preserve the outcome, not the historical workaround or its exact wording.

For each changed behavior, check the implementation or run an isolated probe.
Revisit the lessons that depend on it. Record the verdicts and verification
limits before advancing the pin; a pin means the delta was reviewed, not that
every upstream sentence was adopted. An empty upstream delta needs no body edit.

## Obelisk

**Purpose:** make session-history retrieval reliable and economical for our
Claude Code workflow. Codex history remains available, but the skill is shaped
around Claude's actual friction rather than equal coverage of every host.

The customization earns its place through concrete query examples, a small
working schema, bounded output, batched investigation, and safeguards against
mistaking the current session for independent historical evidence. Keep those
outcomes when changing the implementation or reorganizing the instructions.
The lessons carry the measurements behind them; do not replace the skill with
the broader upstream tutorial merely because that tutorial is newer.

**Adopt:** verified helper/API corrections, better query examples, retrieval
correctness fixes, and runtime improvements that remove a measured failure.
Broaden host coverage when there is a workflow that needs it. Keep infrequent
details in the upstream references rather than expanding the main procedure.

**Update judgment:** distinguish published documentation from installed CLI
capabilities. For an identity-resolution change, check the runtime and the
self-exclusion behavior before relaxing a guard. A synthetic resolver test
does not establish when Claude has persisted a live tool record. Preserve
the query examples unless evidence shows a better way to achieve their goals.

Sources and receipts: [pin](../claude/.claude/skills/obelisk/.upstream/PINNED.txt),
[lessons](../claude/.claude/skills/obelisk/LESSONS.md).

## Tailwind best practices

**Purpose:** retain the owner's condensed, workflow-optimized skill derived
from the purchased `tailwindcss/insiders` rules. The original rules are a
comparison baseline, not a second invokable skill.

**Adopt:** relevant correctness fixes, utility changes, and useful guidance
that fits the current skill's concise structure. Keep the adaptation and its
invocation policy; do not restore the entire upstream document by default.
There is no recorded rationale for every condensation, so a missing upstream
paragraph alone is not evidence that a rule was intentionally rejected.

**Update judgment:** inspect the upstream delta and its relevance to the
adapted body. Preserve private upstream contents outside tracked files; track
only the pin and review decisions. The existing adapted body is tracked in
this public repo; changing its publication or Git history is a separate task.

Sources and receipts: [pin](../claude/.claude/skills/tailwind-best-practices/.upstream/PINNED.txt),
[lessons](../claude/.claude/skills/tailwind-best-practices/LESSONS.md).

## The writing rulebook and its upstream reference

`prompt-engineering` is locally authored, with selected rules absorbed from
the managed `writing-for-agents` skill. It is not a verbatim fork. Its purpose
is one coherent rulebook for model-facing text, shaped by our measured usage.

Judge upstream writing improvements against that purpose; do not create a
second authoritative writing guide. Skill mechanics remain a direct reference
to upstream. The [sync procedure in agent-skills.md](agent-skills.md#the-rulebook-and-its-upstream-sibling--how-they-stay-in-sync)
owns the fold baseline and review method; the rulebook's
[evidence log](../claude/.claude/skills/prompt-engineering/EVIDENCE.md) records decisions.

## Adding another customization

Before treating another skill as a maintained fork, record its purpose, what
must survive updates, the changes worth adopting, and the evidence needed to
retire its local workarounds. Add its source pin and link any lessons. When the
owner's intent is unknown, say what is evidenced and what remains unknown;
do not manufacture a rationale from the diff.

# distill-handoffs — evidence log

Earlier passes (the closeout digest, scope by reasons, the `gwt remove` step,
domain folders) are recorded in `~/dev/brief/EVIDENCE.md`, beside the engine.

## Decisions that stand

- Plain sentences, with every pass, step, heading and command kept (10-29).
- A closeout ends on what follows its work: the brief it hands to, else its
  domain's next unstarted brief, else nothing; never the folder's queue,
  which `brief` no longer offers anywhere (11-18). 159 of 184 planlab
  closeouts had offered the same off-domain brief.

## Open comparisons

1. **Off-domain offers** (11-18): in the next 10 closeouts, closing
   suggestions naming a brief outside the closed branch's domain that the
   work does not hand to. Baseline 159 of 184; target 0. Reverse: the user
   asks for the whole folder's queue after closeouts. Predicates in planlab's
   `.agents/skills/pl-loopy-handoff/EVIDENCE.md` (2026-11-18).
2. **Work the pass left** (10-29): the user's next turn after a sweep report;
   "go cleanup"-style follow-ups mean the pass should have done it.

## 2026-10-29 — plain sentences

**Usage since 09-01** (obelisk, both machines; typed `/distill-handoffs`,
self excluded): 9 runs, mostly itell on the mac and planlab via
`pl-loopy-handoff-distill`. The user's replies were release words or next
work: "delete" for a held deletion (mini `06c0afdf`), "go cleanup" after a
report (mac `fa96cf2e`). None corrected a verdict.

**Changed.** Body 3,044 → about 2,760 words; average sentence 33.7 → 24.1;
em-dashes 52 → 0. Every pass, step number, heading and command is kept:
`pl-loopy-handoff-distill` runs its additions "after step 1 of whichever pass
fires" and cites § Verdicts, § What waits and § Retirement; handoff cites §
Verdicts. The cut is modest because the body is mostly engine contract
(digests, refusals, release words), which carries behavior.

**Deletions to watch** (author's own parity read): "a folder kept on this
machine answers that there is nothing to publish" (`brief sync` says so
itself), and the `path` reason "naming those under each declared directory"
(now "listed in the file for step 2"). Either returns if a pass misreads an
unpublished folder or skips the overlap lists.

**Untested.** No eval case; the sweep needs a handoff folder and gh state.
**Next pass compares** the next user turn after a sweep report. "go
cleanup"-style follow-ups mean the report left work the pass should have
done.

## 2026-11-18 — the closeout's last line is the work's next step

The report ended on `brief closeout`'s `next`, the folder-wide order's first
startable rows, so planlab closeouts offered `pipe-memory-history` in 159 of
184 runs whatever the domain. Step 7 now ends on the brief this work hands
to, else its domain's next unstarted brief, else nothing; the folder note,
the reconcile worklist and § What waits read each domain note's rows as its
order, since the engine (`brief` `0a613f1`) dropped the cross-folder rank.
Case set `skill-evals/cases/pl-loopy-closeout-next`: the old text passed 4.78
of 9 checks per run, this text (`8922a57e`) 9 of 9, and after a fresh
reader's fixes (`2e92de65`) 9 of 9 again. A prompt pass (`214d59b6`) stated
the closing as the first of three cases and dropped the "leave out other
domains" prohibition: 9 of 9 without it (`closeout-next-pass2-1118`). It
returns if a closeout offers another domain's brief the work does not hand to. Paid for within the
2,766-word budget by cuts: a second state-in-notes bullet, the wave-list
line, a repeated `brief mv` pointer, the README-missing clause the worklist
already holds. Any returns if a sweep writes state or wave dates into a note,
or misses a domain folder with no README. Full entry: planlab
`.agents/skills/pl-loopy-handoff/EVIDENCE.md` (2026-11-18).

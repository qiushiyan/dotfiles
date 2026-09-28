# documentation standards — evidence log

Usage evidence for `docs/documentation-standards.md`, the shared standard
this skill and `distill-docs` apply. The standard is broadcast verbatim and
kept under ~14 KB, so its receipts live here.

## 2026-09-28 — first mining pass (improve-tool)

**Corpus.** Obelisk index, Claude sessions 2026-06-26 → 2026-09-28. Readers of
any copy (non-edit tool calls naming `documentation-standards`): 683 sessions,
194 since the shared copy began on 2026-09-11. `/update-docs` + `/distill-docs`
invocations: 106, 23 since 2026-09-05, each read to its next two user turns.
Check-block runs since 09-11 (`git diff --cached` plus the grep's pattern):
changelog 82 sessions, cardinal 79, PR/date 75, table 69, status-page loop 41,
post-merge 36. User-voice sweep: user text in doc-touching sessions since
08-20 on history/philosophy/depth terms, 24 hits read in context.

**Findings and dispositions.**

- **The status-page rule contradicted its only user.** planlab #7973
  (`origin/develop` 6894503677b) retired its status pages after session
  4fc50d59 (09-27) measured 14 sessions / 30 conflict hunks, 17 in per-PR
  owed items; that session's standards proposal was never integrated.
  dotfiles, itell and tabtype each bound the rule only to skip it.
  → Replaced with owed-read markers in the change's record, the
  "no region that every change writes" rule, per-milestone delivery state,
  and a marker grep. Verdict semantics follow the as-merged planlab rule
  (only a confirming comment closes), not the earlier proposal.
- **Docs accrete history and incident notes; the user asks for present
  design and its reasons** (024a9e0e 08-26, abd24d95 09-04, 4ce07439 09-19,
  a0710781 09-24, 4fc50d59 09-27). The Present-state rule already existed.
  → The user's purpose paragraph folded into the opening; lessons entries
  whose hazard is gone are deleted; a predecessor a reader might propose
  again is kept as the alternative the design beats.
- **Docs deeper than the reader acts on** (024a9e0e 08-26, 2eeff918 09-25,
  16b71a86 09-25). → "Mechanism below the reader's action" under what does
  not earn documentation.
- **PR-number rule conflict** (read, no stall observed): § What this change
  can know said docs cite the PR; the check block flags PR numbers in design
  docs. → The change's record cites it.
- **No change:** the other check-block greps (no false-positive complaint
  found in the sample).

**Verification.** The marker grep passes all 55 planlab marker lines on
`origin/develop` except legacy unnumbered ones, and flags a synthetic
unnumbered marker. Two cold readers (a production-read `/update-docs` in a
bindings-light repo; distilling history, incident and mechanism excerpts):
both took the purpose from the opening; their shared-cause findings (where
doubt lives after merge, what closes a read, decision vs history, lessons
retention, bindings location) were repaired. Not repaired: update-docs'
"after a change lands" wording and the `docs/*.md` pathspec default.

**Next pass compares.** Owed-read wording in sessions after the broadcast:
markers in records vs dated items on shared pages; user corrections about
history or mechanism depth after `/update-docs` and `/distill-docs`, against
the five sessions above. Revise if agents drop owed reads entirely (no
marker where production had to answer) or keep narrating predecessors under
the "might propose again" clause. External bindings still name the removed
status-page loop: planlab `pl-loopy-handoff` ("`<status pages>` is empty"),
itell `update-docs`, tabtype `CLAUDE.md`/`AGENTS.md`.

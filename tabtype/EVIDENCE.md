# TabType snippets — evidence log

One entry per mining pass over how the snippets are used; counts are written
so the next pass can re-run them.

## 2026-10-04 — what is expanded, and what is typed by hand instead

Session `77644487`; ledger `tabtype-frictions.md` and the query scripts
(`fp.py`, `gen.py`, `q1.mjs`, `q5.mjs`, `q6.mjs`) in its scratchpad.

**Corpus.** Laptop obelisk index: Claude user turns 2026-06 → 10-04 (12.7k),
Codex 2026-05 → 10-04 (4.7k). The mini's index over ssh: 09-25 → 10-04 (700
Claude turns; sessions moved with `claude-tomini` appear in both).
`~/.config/tabtype/history.json`: 09-27T21:55Z → 10-04 only; a test run reset
it (`test:item-*` rows), fixed in tabtype `cd8ff20`.

**Predicates.** A use is a user turn (`role='user'`, `content_type='text'`,
not meta, not sidechain, not a continuation summary) containing the first
line, to 80 characters and with a leading `/command` stripped, of any
committed version of the snippet's `expand`; the longest match wins. A
slash-led snippet is stored twice (the paste and the `<command-name>` row), so
sessions are the unit, not turns. Hand-typed patterns: Claude turns since
08-05 (8,045 turns, 950 sessions), text cut at the first snippet fingerprint,
turns over 5k characters dropped, regexes in `q5.mjs` and `q6.mjs`.

**Validation.** For 09-27 → 10-04 the fingerprint counts against TabType's
own counter: `implement-spec` 10 vs 10, `review-verify` 2 vs 2, `prompt-check`
7 vs 8, `loopy-review-verify` 15 vs 13, `loopy-prompt-check` 9 vs 8. Mid-body
phrases of the stopped snippets show no later use than the first-line count.

**Limits.** Expansions into non-agent apps are invisible before 09-27.
Planlab's `.tabtype.local.toml` is gitignored, so earlier wordings of the
`loopy-*` keys are undercounted. "Never" means never since May/June.

| finding | evidence | verdict |
|---|---|---|
| 13 keys never expanded | 0 hits, first line and mid-body | removed |
| the hand-carried plan/review loop is dead | 10 keys, last uses 06-22 → 07-31; `/consult` 148 and `/review` 151 sessions in September | removed |
| 8 one-offs | at most 4 uses each, none after 08-07 | removed |
| `write-spec` | 47 uses / 43 sessions, last 08-30; `/write-spec` skill 63 sessions in September | removed on the user's word |
| `compact-for-impl`, `compact-for-review` | 51 / 23 (last 09-16) and 38 / 28 (last 08-21); about 40 laptop sessions ran a bare `/compact` since 09-21. Why the staged form stopped is unknown. | removed on the user's word |
| `handle-review` | 48 / 43, last 08-01; `/pl-handle-code-review` 108 sessions in September, 26 laptop + 14 mini of them typed as "handle (review) once, no poll" | global key removed; planlab-local `loopy-handle-review` carries the typed form |
| `think-holistic` | 101 / 83, last 08-30; no replacement identified | kept on the user's word |
| `loopy-closeout` | last 09-23; "/pl-loopy-handoff-distill merged (and deployed)" typed in 18 + 8 sessions since | shrunk to the typed form |
| "implement end to end" with no spec | 90 sessions in 60 days, 23 + 5 since `implement-spec` came into use on 09-21 | `implement-now` added; "defer doc updates" (64 sessions) left to `rules/docs.md` |
| `consult-codex` | 0 uses since it was added 09-21, against 19 + 8 sessions phrasing the same ask by hand; the user had not known it existed | reshaped: slash-led, cursor at the end |
| standalone spikes | "run some spikes" in 30 sessions / 36 turns over 21 days; 30 turns ask to prove an approach, 6 a diagnosis, 6 name a consult | `spike-check` added; `consult-verify` (2 uses, 09-01) removed |
| consult, then build unless a decision is the user's | 8 laptop + 2 mini sessions, 09-27 → 10-04, voices codex and opus | `consult-then-build` added beside `consult-codex`: the two differ in where they stop |
| "plain terms" | 58 sessions in 60 days, 6 since 09-21 | no snippet; watch |

**Not done.** `WORKFLOW.md`, `DESIGN.md`, `tabtype/CLAUDE.md` and
`docs/doc-loop.md` § write-spec still describe the removed snippets. The
mini's copy of planlab's `.tabtype.local.toml` is unchanged.

**Next pass compares**, from `history.json`, four weeks of counts per key:

- `implement-now`, `loopy-handle-review`, `loopy-closeout`, `consult-codex`,
  `consult-then-build`, `spike-check` each expanded in at least three sessions, and the hand-typed counts for
  "end to end", "no poll", "merged and deployed", "consult round with
  codex" and "run some spikes" lower than above. A key still at zero while its phrase is still typed
  is the wrong wording or the wrong home; revise or remove it.
- Any removed key retyped from memory or pasted from Git history is a removal
  to reverse.

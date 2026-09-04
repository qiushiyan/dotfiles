# Cold-reader prompt

One dispatch per route through the instructions, run as background agents
in parallel. A subagent spawned inside a project receives that project's
`CLAUDE.md` from the harness at spawn — a copy that can be older than disk —
and judges that copy unless told otherwise. The prompt therefore names the
file to read and says the injected copy is not it; a report that quotes
headings the file no longer has is a report on the wrong version and is
re-run. Fill every `<…>`: the scenario is concrete (one runId, one
complaint, one PR), the reading order is the order the skill itself imposes,
and the agent holds no credentials, so it reads and greps but never runs the
engine.

```
You are a cold reader. Pretend you are an agent starting <the situation the
tool serves> with NOTHING in context except what you read now. Repo: <path>
(do not cd elsewhere; do not run any `<cli>` command — you hold no token;
read-only file reads and greps of the repo are fine to verify a claim).

Scenario: <one concrete situation, in the user's words — "a teammate pastes
one id from chat: can you tell me what broke?">

Read the files from disk, in this order, as that agent would — if your
context already holds a CLAUDE.md, ignore it; the file on disk is the one
under review: (1) <entry route or router>,
(2) <the instructions>, (3) only the parts of <satellite> you would actually
reach for. Then read the rulebook
/Users/qiushi/dotfiles/claude/.claude/skills/prompt-engineering/SKILL.md and
judge the files against it.

Report (≤ 90 lines, no edits to any file):
1. THE SEQUENCE you would run, command by command, exactly as the skill
   leads you — and the first point at which you would be unsure what to do
   next, or would have to guess a flag, a path, a field, or a file. Quote
   the line.
2. WHAT WOULD HELP MOST: the 3–5 changes that would most reduce your chance
   of going wrong or stalling, ranked. Each: the problem, the quoted line,
   and a rewrite you would accept in ≤ 3 lines.
3. CUT LIST: lines a cold agent does not need at that point — sprawl,
   duplication, negations that should be positives, reference that belongs
   behind a pointer, prose an existing code example already carries. Quote
   each.
4. ROUTE GAP: does <entry route> get you to <the instructions> at all? What one
   line would.
5. Anything the instructions claim that the repo contradicts — verify by grep
   before saying so and cite file:line.
Be blunt; "this is fine" per section is an acceptable answer when true.
```

Read the reports against each other: a stall two readers hit at the same
line is the first fix; a cut one reader proposes that another reader's
sequence relied on is not a cut.

# Finding classes

Every review finding carries one class tag from this list, after its
severity: `**moderate** · collapsed-outcome`. The tags let a later pass count
what reviews keep catching, ask which review caught it, and move the
prevention upstream. Without them that takes an archaeology pass over old
results. Tag by the defect, not by the fix. Use `other` when nothing fits,
and name the shape in a few words so the list can grow from real cases.

- `unpinned` — a behaviour or wiring that no test pins: revert it and the
  suite stays green, or its test never runs where the PR is gated.
- `wrong-reason-test` — a test that passes for the wrong reason: the fixture
  supplies the value under test, it asserts on a mock or on a call count, or
  it was edited to match the new output.
- `low-value-test` — a test that costs upkeep without guarding a credible
  regression: it restates the implementation, pins wording no caller reads,
  drives a helper the public path already proves, or re-proves another
  file's behaviour (the shapes in `../testing/test-quality.md`). Its fix is
  deletion, or folding it into the test that owns the behaviour.
- `second-mechanism` — a new route beside an existing owner that already
  answers the same question: a parallel queue, policy, decoder or lifecycle,
  or a copied helper.
- `collapsed-outcome` — a partial, failed or unknown result that reaches its
  consumer as empty, success or absent.
- `wrong-granularity` — a check, key or allow-list applied at the wrong unit
  (per path segment instead of per file, per page instead of per section), or
  a refusal that blocks the very thing it asks for.
- `ordering` — a check-then-act gap, crash window, retry or replay hazard, or
  deploy-order skew.
- `unenforced-bound` — a deadline, abort signal or size cap that does not
  reach the code doing the I/O, or a resource held past its use.
- `model-facing` — text a model reads (prompt section, tool description,
  command help, refusal, error, bundled skill) that misleads it, contradicts
  another surface, invites an invented answer, or should be gated in the code
  that assembles it.
- `scope` — a behaviour the change alters outside what its spec or PR
  describes, for any user or surface.
- `unsupported-claim` — a PR body, spec, comment or doc that claims what the
  code does not do. Text a model reads is `model-facing` instead.
- `production-read` — a promised production check or metric that cannot
  answer its question from the fields that exist.
- `structure` — a reshape: a module doing several jobs, a leaking interface,
  a file grown past what one reader holds, a hop that adds nothing.
- `other` — with a few words naming the shape.

---

> _Lesson · collaboration. Distilled 2026-10-07 from a classification of
> 354 findings in 33 PlanLab review rounds (2026-09-24 → 10-06) and two
> fresh-session PR reviews (`~/dotfiles/claude/.claude/skills/strategic-review/EVIDENCE.md`).
> The classes are that corpus's own, with `structure` and `other` added._

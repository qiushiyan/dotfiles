---
name: test-audit
description: "Audit tests against the test-quality lesson: find the fragile behaviour no test guards and the tests that cost upkeep without guarding anything, then repair both at their owners. Scales from the tests one change added to a whole subsystem's suite."
requires:
  - lessons:testing/test-quality.md
---

# Test audit

You are auditing a project's tests so that the suite guards what is likely
to break and stops paying for tests that cannot fail for a real reason. The
complaint that usually starts an audit is that tests are too literal: they
restate the code, pin wording, and spend effort where nothing is likely to
break, while the fragile paths stay thin. Both halves are findings, and the
second is usually the costlier one.

The standard is `~/.config/lessons/testing/test-quality.md`. Read it in
full before judging anything: it names the low-value shapes, one owner per
behaviour, tokens and relations over byte pins, the mutation check, and how
to delete a test safely. This skill is the workflow around it.

Done when every test in scope carries a verdict with its evidence, the
fragile behaviours you named each have a guard you watched fail, and the
edits are made and validated, or the report says what is left and why.

## Scope

The bar is the same at every size; the size sets how much you read.

- **A change**: the tests a branch or PR adds or touches.
- **An area**: one production owner, such as a feature, command or
  package, with every test that drives it wherever that test lives; aim for
  a few high-confidence candidates rather than a large speculative list.
- **A campaign**: a subsystem's test surface too large for one reader,
  pruned in one PR. Read [CAMPAIGN.md](CAMPAIGN.md) before starting one.

Read the project's root and scoped `AGENTS.md` or `CLAUDE.md` and its
testing guide first, for how its tests run, what CI runs, and how to make a
scratch checkout that can run the suites in scope. Discovery changes nothing
outside that scratch checkout. When the user asked only for an assessment,
the report of the risk map and the marks is the deliverable; otherwise go
on to edit.

## 1. Map the risk

Start from the production code, not the test files, because an audit that
starts from the tests spends its effort judging them and never sees the
gaps. Name the few behaviours in scope most likely to break and costliest
when they do: an ordering rule, a bound, an outcome that can collapse to
success, a permission check, wiring between processes or packages. For each,
find the test that owns it, then break the guarded line in the scratch
checkout and run that test. A behaviour that stays green is a gap, whatever
the coverage says. A guard that only the real database or transport can see
belongs at that boundary, not behind a mock.

## 2. Judge the tests

Read each test in full with the production owner it exercises, that
owner's callers, overlapping tests, and the history of both. Judge a test by
its assertions, not its title. Give each test, or each table row that
needs a different verdict, one mark:

- `R` keep, naming the contract and the bug it catches;
- `F` keep the contract but repair the assertion, such as a sentence pin
  loosened to the token a caller depends on;
- `C` consolidate, naming the owner that absorbs it: a table row, a
  stronger boundary suite;
- `D` delete, naming the proof that remains or why no contract exists.

### Retention bar

Keep a test that independently guards a public API, protocol, storage,
migration, config, security or platform contract, or a release or package
contract; call ordering that callers observe; a regression with a credible
failure mode; or exact bytes a model or client parses, held in the one place
the lesson's pin harness describes. Static or slow is not a reason to
delete. A test that resembles the implementation may still be the only
independent proof of a contract; show otherwise before removing it. A
retained test that fails on the baseline is a product bug: reproduce it and
report it rather than deleting the test.

### Candidate evidence

A `C` or `D` is ready only with every field recorded:

- the test's name and location, and the failure it can actually detect;
- the stronger proof that remains, by file and test name;
- the non-test callers of any seam it needs;
- why it exists, from history;
- the production or test-support code its removal unlocks;
- the risk, and the focused command that validates the change.

## 3. Edit

Make one coherent batch per owner boundary. Add the missing guards from the
risk map first, each seen red against the unfixed or mutated line. Then
apply the marks: move retained regressions to their owner, fold
near-duplicates into a table, loosen byte pins to tokens and relations, and
delete the `D` tests together with the exports, flags, wrappers and dead
paths only they used. Write no replacement test that restates the one you
removed, and leave an uncertain candidate in place rather than counting it
as cleanup.

## Validation

1. Run the owner and sibling tests through the runner's own filter, such
   as `go test -run` or a Vitest file path, since a whole monorepo run is
   slow; then run whatever the project requires before shipping.
2. Repeat each mutation from the risk map against the final code, in the
   scratch checkout, and confirm the guard still goes red.
3. Where a removed test claimed a script, plan or generated output, run the
   thing that owns that contract.
4. Run the project's formatter on the changed files and `git diff --check`.
5. Count lines with `git diff --numstat`, production and tooling apart from
   tests and test support.

Commit, push or open a PR only as the project's rules and the user allow.

## Report

Lead with what the suite now guards that it did not, or say the risk map
found each behaviour already guarded. Then:

- the risk map: each fragile behaviour, its guard, and the mutation result;
- each test's mark with its evidence line, and the removed and repaired
  categories with counts, including the false positives you kept and why;
- production simplifications the deletions unlocked, or none;
- production against test line counts;
- what you ran and what rests on reading alone;
- follow-ups, each with the reason it was left.

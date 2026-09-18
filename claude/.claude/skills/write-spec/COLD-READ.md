# Cold read — the comprehension check

[write-spec](SKILL.md) step 4 sends the fenced block below, with its three
paths filled in, to a fresh Opus subagent that holds nothing else. The
writer judges what comes back; the reader never edits the spec.

```text
You are the cold comprehension reader for a design spec. You have no
conversation history, and that is the point: the spec will be read by an
implementing session in the same state, and this pass finds what that
session could not reconstruct.

Inputs:
- Spec: <absolute path>
- Project docs root: <absolute path>
- Glossary: <absolute path, or "none">

Read the summary first. Write down, from the summary alone, the goals, the
scope, the exceptions that change the build, and the dependencies still
outstanding. Then read the rest of the spec, and the project documents you
need to resolve what it says.

Return, with "none" for an empty category:

1. Your summary-only reconstruction, then separately what the body made you
   correct in it.
2. Unresolved terms. For each: the exact wording and where it appears; the
   reading you guessed, or "no defensible reading"; the plausible competing
   reading, if one exists; the implementation choice that would change
   between them, or "unknown"; the documents you checked. Include ordinary
   words used with an unexplained local meaning. A term you resolved from
   the spec or the docs is not a finding; say so rather than manufacture
   ambiguity.
3. What you could not reconstruct: a behaviour, an owner, a legal state, a
   changed path, the status of a premise, or a build gate. For each: where
   the gap or the conflict is, and the implementation choice it leaves open.

A term finding reads like this:

Term: "both legs", § Design — API.
Guessed: the eager staging planner and the lazy resolver.
Alternative: artifact selection and the cache fallback.
Choice that changes: which callers must share the selection rule, and which
may make a retention request.
Checked: the spec, docs/loopy/infra/client-data-corpus.md.

Give conclusions with their evidence, not a reasoning transcript. Use only
the spec and the project docs. Do not read implementation code, run
anything, edit anything, or fill a gap by inventing a design; the task is
comprehension, not a second design review.
```

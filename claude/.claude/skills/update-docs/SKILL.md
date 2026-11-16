---
name: update-docs
description: Use when the user wants docs updated to reflect recent or shipped changes, e.g. "sync docs".
---

# Update the docs

Leave the docs so the next agent knows what the code cannot tell it. Read the
repo's `documentation-standards.md` and its bindings first, or
`~/dotfiles/docs/documentation-standards.md` where it has none. Done is the
docs true and no longer than they need to be, any edits committed on the
change's branch (a new commit when the change is already committed), and a
report.

1. **Record what the work learned.** Ask what this change taught that the code
   does not show: a moved boundary or owner, an invariant created or found
   unguarded, a decision (what it beat, what reopens it), a changed route into
   the code. Look in the review findings fixed, the guards added, what the
   user decided, and what the first attempt got wrong. Each answer is one
   entry, folded into the section that owns it; a part the work did not
   establish, such as a decision's reason, is asked of the user, never
   inferred. With no answers, the result
   is "no doc change, because …"; records the bindings name are still
   written.
2. **Cut what the change made false.**
   `~/.agents/skills/update-docs/scripts/doc-check --stale --base <the commit
   before the change>` lists doc lines that name what the change removed,
   committed or not; grep the docs too for any gap the change closed or term
   it replaced. Cut each such line to the rule it carried, or delete it.
   Where a doc states an obligation the code now breaks, ask whether the code
   or the design is wrong.
3. **Check.** Stage the docs and run
   `~/.agents/skills/update-docs/scripts/doc-check --since <default branch>`
   from the repository, with the bindings' live-doc pathspecs as separate
   arguments, then any check the bindings add. Fix each failure, and fix each
   candidate or say why it stands. A new doc gets a route from the index. A
   doc that grew reruns with `--grew '<doc>=<kind>: <why>'`, and its
   `Doc-Change:` line goes in the commit message.

Asked to reshape the docs, the scope is the docs named. Make the reshapes the
work calls for (fold a shipped spec into its doc, create, merge or split a
doc, add or drop an instruction-file line) and report each; ask first where
docs and code disagree on the design itself, or where the bindings say to.

**Report:** what was recorded and where, or "no doc change" and why; what was
cut; each `Doc-Change:` reason; the reshapes.

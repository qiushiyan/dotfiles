---
name: wiki
description: >
  Personal wiki at ~/wiki, the canonical home for durable personal context.
  Context: a session needs facts about the user (employment, visa, money, health, preferences),
  a preamble about who they are, or "which of my projects does this affect?".
  Ingest: "记到 wiki" / "add this to the wiki", or a durable decision lands mid-session.
  Maintain: lint/sync the wiki, or a session starts inside ~/wiki.
---

# wiki

`~/wiki` is a private git repo of markdown topic pages about Qiushi. `~/wiki/CLAUDE.md` holds the conventions and iron rules — read it before writing there. `~/wiki/index.md` is the one-screen map: navigate from it, then grep (filenames are self-documenting).

Three operations; pick by intent.

## context — answer from the wiki, or assemble a preamble

1. Read `~/wiki/index.md`, pick the relevant topic pages, read them (hubs route into their folders).
2. Answer with citations to the pages, or assemble the requested preamble. **Preambles and briefs omit literal identifier values** (NINO, account numbers) — say "NINO confirmed", not the number — unless the user asks; briefs get fanned to third-party models.
3. A page that contradicts the session's newer information: say so, and offer an ingest.

## ingest — write new material back

1. Read what the wiki already records about the object (index → grep, including any propagation table naming it) and, for a store or repo, its current state. A decision that contradicts the recorded state is written as a change from that state, not as a fresh fact.
2. Classify: a fact or decision changes a topic page; undistilled material becomes an inbox item; an original document goes through `/add-source`.
3. Update the affected topic pages, respecting their update-trigger lines; a locked snapshot in another repo gets a one-line pointer, never a rewrite.
4. Material touching connected dev projects: the fan-out guide in `~/wiki/projects/index.md` names the targets; each target page's propagation table sets the row shape (`projects/snippets.md` for snippet-family changes, which also rerun `~/wiki/scripts/snippet-inventory.sh`).
5. Delete the consumed inbox item; commit with a substantive message. Push is manual.

## maintain — the checkpoint

Run `~/wiki/scripts/lint.sh`; the *maintain* rule in `~/wiki/CLAUDE.md` says what to report, what to repair directly, and what waits.

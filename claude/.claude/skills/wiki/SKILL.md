---
name: wiki
description: >
  Read from or write to the personal wiki at ~/wiki — the canonical home for durable
  personal context (profile, finance, housing, health, interests, learning, connected projects).
  Context: when a session needs personal facts (employment, visa, money, health, preferences),
  a brief preamble about who the user is, or "which of my projects does this affect?".
  Ingest: when the user shares an article/decision/fact worth keeping, says "add this to the wiki",
  "记到 wiki", or a durable conclusion lands mid-session.
  Maintain: when asked to lint/sync the wiki or a session starts inside ~/wiki.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - Bash
---

# wiki

The wiki at `~/wiki` is a private git repo of markdown topic pages. `~/wiki/CLAUDE.md` carries the conventions and iron rules — read it before writing anything there. `~/wiki/index.md` is the one-screen map; start navigation from it, then grep (filenames are self-documenting).

Three operations. Pick by intent, not by which tool is nearest:

## context — answer from the wiki, or assemble a preamble

1. Read `~/wiki/index.md`, pick the relevant topic pages, read them (hubs route into their folders).
2. Answer with citations to the pages, or assemble the requested brief preamble from them.
3. **Preambles and briefs omit literal identifier values** (NINO, account numbers) — reference the fact ("NINO confirmed") not the value, unless the user explicitly asks. Briefs get fanned to third-party models.
4. If a page you relied on contradicts the session's newer information, say so — and offer an ingest.

## ingest — write new material back

1. Classify: does this change a topic page (fact/decision), start an inbox item (undistilled), or archive an original (into `sources/`, mode 444, gitignored subfolders for identity/contract material + `sources/BACKUP.md` row)?
2. Update the affected topic pages (respect update-trigger lines and the living-vs-locked rule in `~/wiki/CLAUDE.md`).
3. If the material affects connected dev projects, consult `~/wiki/projects/index.md`'s fan-out guide and append a propagation row to the relevant page (`projects/snippets.md` for snippet-family changes): target, status (`applied` / `deliberately skipped` / `deferred` + reason), date, ref. A `deferred` row is open work — lint flags it.
4. Delete the consumed inbox item; commit with a substantive message (the commit log is the journal).

## maintain — the checkpoint

Run `~/wiki/scripts/lint.sh`; report every flag with a proposed fix, fix only what the user confirms (mechanically safe repairs — broken links, index drift, a renamed card pointer — may be applied directly, each named in the report). After snippet-store changes anywhere, `~/wiki/scripts/snippet-inventory.sh` regenerates the inventory.

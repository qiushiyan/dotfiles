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
---

# wiki

`~/wiki` is a private git repo of markdown topic pages. `~/wiki/CLAUDE.md` holds the conventions and iron rules — read it before writing there. `~/wiki/index.md` is the one-screen map: navigate from it, then grep (filenames are self-documenting).

Three operations; pick by intent.

## context — answer from the wiki, or assemble a preamble

1. Read `~/wiki/index.md`, pick the relevant topic pages, read them (hubs route into their folders).
2. Answer with citations to the pages, or assemble the requested preamble from them. **Preambles and briefs omit literal identifier values** (NINO, account numbers) — say "NINO confirmed", not the number — unless the user asks; briefs get fanned to third-party models.
3. A page that contradicts the session's newer information: say so, and offer an ingest.

## ingest — write new material back

1. Classify: a fact or decision changes a topic page; undistilled material becomes an inbox item; an original document is archived into `sources/` (mode 444; identity/contract material in a gitignored subfolder with a `sources/BACKUP.md` checksum row).
2. Update the affected topic pages, respecting their update-trigger lines and the living-vs-locked rule.
3. Material that affects connected dev projects: follow the fan-out guide in `~/wiki/projects/index.md` and append a propagation row to the relevant page (`projects/snippets.md` for snippet-family changes) — target, status (`applied` / `deliberately skipped` / `deferred` + reason), date, ref.
4. Delete the consumed inbox item; commit with a substantive message (the commit log is the journal). Push is manual.

## maintain — the checkpoint

Run `~/wiki/scripts/lint.sh` and report every flag with a proposed fix; which repairs are safe to apply directly is the *maintain* rule in `~/wiki/CLAUDE.md`. After snippet-store changes anywhere, `~/wiki/scripts/snippet-inventory.sh` regenerates the inventory.

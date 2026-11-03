---
name: emil-design
description: UI design driven by Emil Kowalski's aiforui skills, deciding through prototyped variants. Use when the user asks for emil-design, or names the emil or aiforui skills for UI work.
---

# Design a UI change with Emil's skills

Take one UI change from the user's complaint to a built design they chose
from live variants. You are done when the user has picked a direction in a
running prototype, the decision and its rejected options are written down,
and the promoted code has had its polish and review passes.

## The skills

The 28 course skills live at `~/dev/aiforui-skills/<name>/SKILL.md` and are
not installed, so loading one by name fails. Read each by path, including
any sibling one of them names. In a brief, doc or record another session may
read, write the path with `~`, because the laptop's home differs from the
minis'.

Read `~/dev/aiforui-skills/README.md` first. It is the map: the phases,
§ Choosing skills, the conflicts found against real design systems, and
§ emil-prototype in practice. When applying a skill teaches something the
README lacks, such as a new conflict or a harness adjustment, add a sentence
to the section it belongs to.

The skills decide what to do; the project's design doc and components decide
the values. Where they disagree, follow the project and list each
disagreement in your report.

## 1. Choose the loadout

The core is fixed: `emil-prototype`, which itself loads
`emil-design-foundations`, `emil-ui-polish` and
`emil-touch-and-accessibility`. This is the course's prototype skill; the
personal `prototype` skill is for logic and state models.

Add one or two material skills that the complaint names, mapped through the
README's § Choosing skills. Use `emil-product-thinking` only when whether to
build the thing is still open. Name each skill in your reply with one line
on why and the stage it serves.

## 2. Look at it live, then split the findings

Walk the UI as its users do before reading code: the real roles and data,
desktop and 390px wide, and the worst content (the longest name, forty rows,
the empty state).

Split what you find. Fixes that hold whichever direction wins are built
directly, ahead of the prototype. Open decisions go to the prototype, as the
directions you would build. Product questions only the user can settle get
the default you would take. Your first reply gives the loadout and this
split; build once the user answers.

## 3. Prototype

Run `emil-prototype` with the README's adjustments for real apps. Where the
project has its own harness, such as planlab's `pl-prototype-bar` in the main
app, use it instead of `PICKER.md`, and meet its conditions for rendering:
planlab's bar shows only under a preview identity, which its skill
describes.

## 4. Hand over a preview the user can open

The user often reads your work from another machine, such as the laptop
over ssh or Rex, so a `localhost` link reaches nothing. On a mini
(`~/.config/machine` reads `mini` or `mini2`):

- Publish the dev server with `tailscale serve --bg --https=<port>
  http://127.0.0.1:<dev port>` on a port that `tailscale serve status` does
  not already list. On mini2 the CLI is
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale`, not on `PATH`. The
  host name comes from `tailscale status --json` (`.Self.DNSName`).
- Make the app accept that origin. Sign-in callbacks and dev allowed-origin
  lists usually name localhost (planlab: `PLANLAB_DEV_ALLOWED_ORIGINS`), and
  a magic link then lands on an error page.
- Open the exact link in `agent-browser`, sign in as the user will, and
  reach the picker before you hand it over.

After `emil-prototype`'s comparison table, give that link, the account and
sign-in steps, the route, and the URL parameter or keys that switch
variants. Then wait for the choice.

## 5. After the choice

- A reply that takes parts from several variants is a mix. Run
  `emil-prototype/MIX.md`, which its `SKILL.md` never links: show its
  matrix and stop, then build the ticked rows as a new variant beside the
  originals, so it has to beat them on the page.
- When the user settles, write the decision with its rejected options where
  the project keeps design decisions (a spec, a design doc, the PR body). If
  the project has no such place, ask where. An alternative the user wants
  kept goes there with the gist of how to build it.
- Promote the winner and remove the harness, unless the user keeps a picker
  or control panel on purpose, such as a staging panel for tuning.

The build often runs under the user's `consult-then-build` snippet. Its
stop still applies: the report, before any PR.

## 6. Polish and review the promoted code

Run `emil-ui-polish` over the integrated code, since the prototype applied
it only to throwaway variants. Then run `emil-ui-review` on the diff and fix
its blocking and should-fix findings. Your report gives its verdict, what
you fixed, and what you checked only by reading.

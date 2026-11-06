---
name: emil-design
description: UI work through Emil Kowalski's aiforui skills, from prototyped variants to the ship check. Use when the user asks for emil-design, or names the emil or aiforui skills.
---

# Design a UI change with Emil's skills

Take one UI change from what the user says is wrong to built code. You are
done when the user has made any open decision on live variants, it is written
down with its rejected options, and step 6 has run on the real code.

## The skills

The 28 course skills live at `~/dev/aiforui-skills/<name>/SKILL.md` and are
not installed, so loading one by name fails. Read each by path, including a
sibling one sends you to. In a brief or record another session may read,
write the path with `~`: the laptop's home differs from the minis'.

Read `~/dev/aiforui-skills/README.md` first. It is the map, and it holds the
conflicts found against real design systems and the harness adjustments for
real apps. When applying a skill teaches something it lacks, add a sentence
to the section it belongs to.

The skills decide what to do; the project's design doc and components decide
the values. Where they disagree, follow the project and list each
disagreement in your report.

## 1. Pick the route

Decide from the request; when it is unclear, prototype.

- **Prototype:** the direction is open. Steps 2 to 6.
- **Improve:** the user knows the change or says no prototype. Walk the UI as
  in step 2, then build without stopping, using the skills README § Choosing
  skills maps each complaint to, then step 6.
- **Finish:** the user has picked a variant, or the UI is already built, as in
  an open PR. Step 5 if a prototype is still up, then step 6.

Skills the user names join the run. Beyond `emil-prototype`'s own loadout, run
one or two at a time and look at the screen between runs: each skill is a bar
the work must clear, and several at once muddle it.

## 2. Look at it live, then split the findings

Walk the UI as its users do before reading code: the real roles and data,
desktop and 390px wide, and the worst content (the longest name, forty rows,
the empty state).

Split what you find. Fixes that hold whichever direction wins are built
directly, ahead of the prototype. Open decisions go to the prototype, as the
directions you would build. Product questions only the user can settle get
the default you would take. Your first reply gives this split and the
loadout from `emil-prototype` Phase 3, each skill with one line on why. Then
stop and build once the user answers: the answer steers the variants.

## 3. Prototype

Run `emil-prototype` (the course's; the personal `prototype` is for logic and
state models) with the README's adjustments. Where the project has its own
harness, such as planlab's `pl-prototype-bar`, use it instead of `PICKER.md`
and meet its conditions for rendering.

Put a choice that cuts across variants, such as a font or a nav mode, on the
control panel beside the numbers, with a button that copies the settings, so
the user's reply is a paste.

## 4. Hand over a preview the user can open

The user often reads your work from another machine, so a `localhost` link
reaches nothing. On any machine:

- Publish the dev server with `tailscale serve --bg --https=<port>
  http://127.0.0.1:<dev port>` on a port `tailscale serve status` does not
  list. On mini2 the CLI is
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale`. The host name is
  `.Self.DNSName` in `tailscale status --json`.
- Make the app accept that origin: sign-in callbacks and dev allowed-origin
  lists usually name only localhost.
- Open the exact link in a fresh, signed-out `agent-browser` session, then
  sign in and reach the picker as the user will. A link that works only in
  your session is a 404 for the user.

After `emil-prototype`'s comparison table, give that link, the account and
sign-in steps, the route, and the URL parameter or keys that switch variants.

## 5. After the choice

- A reply that takes parts from several variants is a mix. Run
  `emil-prototype/MIX.md`, which its `SKILL.md` never links: show its matrix
  with the rows you would take and stop, then build the ticked rows as a new
  variant beside the originals, so it has to beat them on the page. If the
  user leaves the parts to you, skip the matrix: state the base you chose,
  build that variant, and list each part with its source and cost.
- When the user settles, write the decision with its rejected options where
  the project keeps design decisions (a spec, a design doc, the PR body), or
  ask where. An alternative the user wants kept goes there with the gist of
  how to build it.
- Promote the winner as `emil-prototype` Phase 7 says, and remove any origin
  allowance step 4 added. A project's harness retires by its own skill's
  rules. A picker or control panel the user keeps on purpose stays.

## 6. Close on the real code

Run these on this run's diff, or the PR's when the run made none. A
prototype's polish does not carry over: integration breaks what it never met.

1. `emil-ui-polish`.
2. `emil-ui-review`. Fix its blocking and should-fix findings.
3. `emil-prep-for-prod <changed paths>`, reading its lanes yourself: at this
   scope its subagent fan-out costs more than it finds.

One report gives each verdict, what you fixed, what you checked only by
reading, what still needs a device or a person, and a link to the built UI as
in step 4.

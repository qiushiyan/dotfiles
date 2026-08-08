# Ghostty fonts — why bold barely reads

The font block looks misconfigured and isn't. **Dank Mono ships three faces and a
bold 12% heavier than its regular**, so emphasis — Claude Code's tool names, `man`
headings, a bold prompt segment — nearly disappears. Every weight-side fix trades
away something worth more, so emphasis is carried by **colour** instead, per
theme. This doc is why.

## The measurement

Ink coverage over `H n o e s`, normalized to em² (fontTools `AreaPen`):

| face | ink | vs its own regular |
|---|---|---|
| Dank Mono Regular | 0.4606 | — |
| Dank Mono **Bold** | 0.5172 | **+12%** |
| Berkeley Mono Regular | 0.5849 | — |
| Berkeley Mono Bold | 0.8014 | +37% |
| Berkeley Mono ExtraBold | 0.9428 | +61% |
| Berkeley Mono Black | 1.0804 | +85% |

A normal bold lands around +40%. Dank Mono's bold is lighter than Berkeley
Mono's *regular*.

## Two things the family simply lacks

- **No weight above 700.** Ghostty's two in-family levers — `font-style-bold` (a
  named style inside the family) and `font-variation-bold` (a variable weight
  axis) — both need a family with somewhere heavier to go. Dank Mono is static
  and tops out at Bold, so neither applies.
- **No bold-italic face.** Ghostty synthesizes one (`font-synthetic-style`
  defaults to `bold,italic,bold-italic`) or falls through to the
  `IosevkaTerm Nerd Font` fallback line.

## font-thicken works against it

`font-thicken = true` runs at the default `font-thicken-strength = 255` — the
maximum — and dilates *every* glyph. It adds weight to regular and bold alike,
closing the small gap that exists. Lowering the strength widens the contrast;
`0` is the lightest thickening, not off.

## Rejected: borrowing bold from another family

`font-family-bold = IosevkaTerm Nerd Font Mono` buys +65% and resolves cleanly,
but bold then changes *typeface* mid-sentence — Iosevka is 0.50 adv/em against
Dank Mono's 0.55, with a taller x-height. Tried, and reverted: the inconsistency
read worse than the weak bold.

## Traps

- **Naming any `font-family-bold` replaces the inherited chain rather than
  extending it** — the primary's fallbacks (Nerd icons, the CJK codepoint map)
  are gone for bold unless re-appended. Repeated `font-family*` lines append; an
  empty value resets.
- **`font-style-bold` is never validated.** A wrong style string passes
  `+validate-config` and silently falls back to whatever the family offers.
- **The second `font-family = IosevkaTerm Nerd Font` line is live**, not
  leftover — that repetition is what makes it a fallback.
- **`+show-face` prints the *typographic* family**, so it cannot tell weights
  within one family apart (every Berkeley Mono weight reports `Berkeley Mono`).
  It does distinguish different families, which is what makes it useful here.

## What ships instead: colour, not weight

The weight problem is routed around rather than solved. Emphasis is marked by
**`bold-color`, set per theme by `theme-set`** — `ghostty_block()` emits a
literal colour from each theme's own palette beside its `theme` line
(→ `docs/theming.md`).

A **literal** colour rather than `bright` is the load-bearing choice: Ghostty's
docs say only a literal "will always be used for the default bold text color",
and bold drawn in the default foreground is most of what matters here. `bright`
alone reaches only bold that already carries an ANSI colour.

The cost, accepted: every bold in the terminal takes the colour — prompt
segments, `man` headings, all of it — and coloured bold silently upgrades to its
bright palette variant. It still reads better than the weight ever did.

## Remaining levers, if colour stops being enough

- **Lower `font-thicken-strength`** (untried). Free; recovers the compressed 12%
  rather than creating contrast.
- **Switch family.** Berkeley Mono is installed and publishes Thin→Black under
  one typographic family, so `font-style-bold = ExtraBold` buys +61% with no
  typeface change — at the cost of Dank Mono's cursive italic, which is the
  whole reason to be on it.

## Future direction — build the weight the family never shipped

The only route to real weight contrast *without* leaving Dank Mono is to
manufacture the missing face: embolden Dank Mono Bold, install it as its own
style, point `font-family-bold` at it. Not built — recorded so the next attempt
starts from the findings rather than from scratch.

1. `brew install fontforge` (not currently installed).
2. `Element → Styles → Change Weight` on
   `~/Library/Fonts/DankMonoNerdFontMono-Bold.otf`, driven by `fontforge -script`
   so the build is repeatable rather than a one-off GUI session.
3. Distinct style name, install to `~/Library/Fonts`, confirm with
   `ghostty +show-face --style=bold`.
4. Target ~+40% ink over regular (0.46 → ~0.65 on the scale above). Measure with
   the same fontTools `AreaPen` pass; the whole point is that eyeballing weight
   is what produced a 12% bold in the first place.

Three things that make it more than an afternoon:

- **Thin strokes balloon** as weight is added, so it is iterate-and-measure.
  Extrapolating from a hairline keeps fine features fine.
- **The artifact cannot live in this repo** — a binary, derived from a commercial
  font, in a public repo. It is a local-only build, so it needs a `MIGRATION.md`
  note and a re-run on any new machine.
- **Dank Mono is commercial.** Whether modification is permitted is a EULA
  question to settle before building, not after.

## Verifying

```bash
ghostty +show-face --string=Bash --style=bold   # which face bold resolves to
ghostty +show-face --cp=0xF07C --style=bold     # icon coverage within bold
ghostty +validate-config                        # syntax only — not font availability
```

macOS has no external config reload; press ⌘⇧, in Ghostty.

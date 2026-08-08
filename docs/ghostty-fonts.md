# Ghostty fonts

The font block looks misconfigured twice over and is correct both times.

- **Bold barely reads** — Dank Mono's bold is 12% heavier than its regular, and
  every weight-side fix costs more than it buys, so emphasis rides on **colour**.
- **汉字 came out small** — a CJK fallback is scaled by *its own line height*
  against the primary's, so the fallback has to be chosen on that number rather
  than on how the glyphs look in a specimen.

Both were settled by measurement, not impression. The method is at the bottom;
it is the part worth keeping.

## Bold barely reads

**Dank Mono ships three faces and a bold 12% heavier than its regular**, so
emphasis — Claude Code's tool names, `man` headings, a bold prompt segment —
nearly disappears.

### The measurement

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

### Two things the family simply lacks

- **No weight above 700.** Ghostty's two in-family levers — `font-style-bold` (a
  named style inside the family) and `font-variation-bold` (a variable weight
  axis) — both need a family with somewhere heavier to go. Dank Mono is static
  and tops out at Bold, so neither applies.
- **No bold-italic face.** Ghostty synthesizes one (`font-synthetic-style`
  defaults to `bold,italic,bold-italic`) or falls through to the
  `IosevkaTerm Nerd Font` fallback line.

### font-thicken works against it

`font-thicken = true` runs at the default `font-thicken-strength = 255` — the
maximum — and dilates *every* glyph. It adds weight to regular and bold alike,
closing the small gap that exists. Lowering the strength widens the contrast;
`0` is the lightest thickening, not off.

### Rejected: borrowing bold from another family

`font-family-bold = IosevkaTerm Nerd Font Mono` buys +65% and resolves cleanly,
but bold then changes *typeface* mid-sentence — Iosevka is 0.50 adv/em against
Dank Mono's 0.55, with a taller x-height. Tried, and reverted: the inconsistency
read worse than the weak bold.

### Traps

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

### What ships instead: colour, not weight

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

### Remaining levers, if colour stops being enough

- **Lower `font-thicken-strength`** (untried). Free; recovers the compressed 12%
  rather than creating contrast.
- **Switch family.** Berkeley Mono is installed and publishes Thin→Black under
  one typographic family, so `font-style-bold = ExtraBold` buys +61% with no
  typeface change — at the cost of Dank Mono's cursive italic, which is the
  whole reason to be on it.

### Future direction — build the weight the family never shipped

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

## CJK — the fallback's line height sets the size

A 汉字 occupies two cells, and the cells belong to the **primary** font. Ghostty
fits the fallback glyph into that box with two clamps, each capped at 1:

```
scale = min(1, primary line height ÷ fallback line height)
      × min(1, two cells ÷ CJK advance)
```

Against the shipped primary — Dank Mono at 0.55 adv/em and 1.142 em line, with
`adjust-cell-width = -2%` giving a 0.539 em cell and a **1.078 em** two-cell box:

| CJK fallback | CJK adv | line | scale | ink fills the box |
|---|---|---|---|---|
| Heiti SC *(system)* | 1.000 | 1.03 | 1.000 | 81% *(predicted)* |
| LXGW WenKai Mono | 1.000 | 1.169 | 0.977 | **78%** *(measured)* |
| **Sarasa Term SC** ← shipped | 1.000 | 1.250 | 0.914 | **78%** *(measured)* |
| PingFang SC *(system)* | 1.000 | 1.400 | 0.816 | 67% *(predicted)* |
| Maple Mono NF CN | 1.200 | 1.320 | 0.777 | **65%** *(measured)* |

**A font named for CJK can be the worst pick.** Maple Mono NF CN is a 1:2 CJK
coding font and rendered *smallest* of everything tried: its 1.2 em advance does
not fit a 1.078 em box **and** its 1.320 em line is the tallest in the table, so
both clamps fire and multiply. Sarasa is a whole tier better despite a *worse*
line height than LXGW, because its glyphs are drawn larger inside the em.

That last row is why the model is a guide, not an oracle: it predicts Sarasa 5%
smaller than LXGW, and on screen the two are indistinguishable. Rank with it,
then look.

### The one number that names the symptom

**汉字 ink height ÷ Latin cap height: 1.07× under Maple, 1.29× after.** A CJK
glyph barely taller than a capital letter is the entire "又小又扁" complaint.
Below roughly 1.2× it reads as undersized whatever the typeface.

### adjust-cell-height is pure air for CJK

Ghostty **centres the glyph vertically** in the taller cell, so every point of
`adjust-cell-height` becomes padding above and below. At 15% — a value tuned for
Latin alone — 汉字 ink was 67% of the line box; 8% measured 71%. It buys nothing
horizontally, and `adjust-cell-width` is the mirror image: widening the cell only
widens the gap, because the width clamp is already satisfied at 1.0 em.

### The codepoint-map ranges were their own trap

`U+4E00-U+9FFF,U+FF00-U+FFEF=Maple Mono NF CN` looked complete and was not.
**A mapped range the font does not cover falls through in silence.**

- Maple covers **7%** of `U+FF00-U+FFEF` and **0%** of `U+3400-U+4DBF`.
- `U+3400-U+4DBF` (Ext A) landed in **Noto Serif CJK SC** — serif, mid-sentence.
- `U+F900-U+FAFF` (compat ideographs) landed in **PCMyungjo** — a Korean font.
- `U+3000-U+303F` (、。《》【】) was never mapped at all; it reached Maple through
  the fallback chain rather than the map, which is luck, not configuration.

The shipped range closes all four, and Sarasa and LXGW cover 91–100% of each:

```
U+2E80-U+303F,U+3400-U+4DBF,U+4E00-U+9FFF,U+F900-U+FAFF,U+FF00-U+FFEF
```

### Sarasa: Term, not Mono

`Sarasa Mono SC` draws `—` and `…` full-width (1.0 em = two cells), but Ghostty
counts East Asian Ambiguous as one cell, so they overrun their box.
**`Sarasa Term SC`** draws them at 0.5 em, which is what the grid expects.
`Sarasa Fixed SC` is the same again minus `calt` — no ligatures.

### Rejected: a 1:2 family as the primary

`font-family = Sarasa Term SC` makes the cell 0.5 em and two cells exactly
1.0 em, so both clamps land on 1.0 and fill reaches 89% — the best number
available. Not taken, for the same reason as the bold section: it costs Dank
Mono's cursive italic, which is the whole reason to be on it.

### The A/B block

Three `font-codepoint-map` lines sit in the config with **exactly one live**;
moving the `#` switches fallback in one edit. Repeated `font-codepoint-map` lines
*append*, so two live lines mean two mappings, not a replacement.

## Verifying

```bash
ghostty +show-face --string=Bash --style=bold   # which face bold resolves to
ghostty +show-face --cp=0x4E2D                  # which face a CJK codepoint lands in
ghostty +show-face --cp=0xF07C --style=bold     # icon coverage within bold
ghostty +list-fonts | grep -v '^ '              # families — monospace only, so most
                                                # CJK fonts never appear here even
                                                # though a codepoint map can use them
ghostty +validate-config                        # syntax only — not font availability
```

`ghostty` is not on `$PATH`; it lives at
`/Applications/Ghostty.app/Contents/MacOS/ghostty`. macOS has no external config
reload — press ⌘⇧, in Ghostty.

**Size claims come from screenshot pixels, never from impressions.** Screenshot a
retina window, threshold the image, and read ink runs by column and row: the CJK
ink run against its pitch gives fill directly, row bands give the line box, and
Latin cap height calibrates the em (`0.650 × font-size × 2` for Dank Mono).
Ratios survive an unknown screenshot scale; absolute pixels do not.

Eyeballing weight is what produced a 12% bold. Eyeballing size is what kept a
65%-fill CJK font in place for months.

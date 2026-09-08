# Ghostty fonts

## Ownership and resolution

`ghostty/.config/ghostty/config` owns the primary font, symbol fallbacks and CJK
mapping. Read its font block for current families and size. Theme switching
owns colours, including bold emphasis, independently of font selection
(→ `docs/theming.md`).

**Repeated `font-family` entries append an ordered fallback list.** Reading
only the last line misidentifies the primary. A Nerd Font fallback supplies
missing icons without making the primary a patched Nerd Font. Keep intentional
fallbacks labelled and experiments out of the live block. An empty family value
resets the list; style-specific families have their own lists.
[Ghostty reference](https://ghostty.org/docs/config/reference#font-family).

Font resolution depends on glyph and style. `+show-config` and `+show-face`
inspect what a new process loads; they do not query an existing window's state.
Use them before inferring a family from a screenshot. Syntax validation alone
cannot establish font availability or whether a requested style exists.

## Verifying

The executable is `/Applications/Ghostty.app/Contents/MacOS/ghostty`;
substitute that path for `ghostty` when it is absent from `PATH`.

```bash
ghostty +show-config                          # resolved families and settings
ghostty +show-face --string=Bash --style=bold # family used for bold Latin
ghostty +show-face --cp=0x4E2D                # CJK mapping
ghostty +show-face --cp=0xF07C --style=bold   # Nerd icon coverage in bold
ghostty +list-fonts                          # installed monospace families/styles
ghostty +validate-config                     # syntax, not font availability
```

Check representative Latin, icons and CJK in `regular`, `bold`, `italic` and
`bold_italic`. `+show-face` reports the typographic family, so it distinguishes
families but cannot prove which weight within Berkeley Mono was selected.
Mapped CJK families can work even when absent from the monospace font listing.
Reload with **⌘⇧,**; codepoint-map changes require a new terminal surface.

## Choosing a CJK fallback

**Fallback size depends on the primary font's cell geometry.** Changing the
primary invalidates tuning based on another family's line height and advance.
Ghostty fits CJK glyphs to the primary's grid; increasing cell height adds
vertical air. Choose a fallback using its metrics, then verify its rendered size.

A mapped range with missing glyphs silently falls through. The codepoint map
covers punctuation and compatibility ranges as well as common ideographs;
keep those ranges when changing the target family. Edit the existing mapping
when comparing fonts, since repeated mapping entries append.

Sarasa **Term** is intentional: `—` and `…` have a 0.5 em advance that fits
Ghostty's single-cell treatment of East Asian Ambiguous characters. Sarasa
Mono gives them 1.0 em and can overrun the cell. Sarasa Fixed omits ligatures.
The Homebrew Sarasa bundle is large, but keeping package-managed installation
avoids maintaining a hand-downloaded SC-only font archive.

## Measurement reference

These measurements describe the tested fonts and Dank Mono cell configuration.
They are evidence for future tuning, not defaults to copy into another family.

### Weight contrast

Ink coverage over `H n o e s`, normalized to em² with fontTools `AreaPen`:

| face | ink | vs its own regular |
|---|---|---|
| Dank Mono Regular | 0.4606 | — |
| Dank Mono **Bold** | 0.5172 | **+12%** |
| Berkeley Mono Regular | 0.5849 | — |
| Berkeley Mono Bold | 0.8014 | +37% |
| Berkeley Mono ExtraBold | 0.9428 | +61% |
| Berkeley Mono Black | 1.0804 | +85% |

Dank Mono has no weight above Bold and no native bold-italic face. Thickening
all glyphs also thickens regular, which can reduce the perceived weight gap;
`font-thicken-strength = 0` is the lightest thickening, not off.
Borrowing Iosevka bold measured +65% but changed typeface within a sentence
(0.50 adv/em versus Dank Mono's 0.55). Berkeley ExtraBold provides a heavier
in-family option; a style name must be checked against the installed faces.

### CJK scaling with Dank Mono

The model used to rank candidates caps each factor at 1:

```
scale = min(1, primary line height ÷ fallback line height)
      × min(1, two cells ÷ CJK advance)
```

Dank Mono: 0.55 adv/em, 1.142 em line; `adjust-cell-width = -2%` gives a
0.539 em cell and 1.078 em CJK box.

| CJK fallback | CJK adv | line | scale | ink fills the box |
|---|---|---|---|---|
| Heiti SC *(system)* | 1.000 | 1.03 | 1.000 | 81% *(predicted)* |
| LXGW WenKai Mono | 1.000 | 1.169 | 0.977 | **78%** *(measured)* |
| **Sarasa Term SC** | 1.000 | 1.250 | 0.914 | **78%** *(measured)* |
| PingFang SC *(system)* | 1.000 | 1.400 | 0.816 | 67% *(predicted)* |
| Maple Mono NF CN | 1.200 | 1.320 | 0.777 | **65%** *(measured)* |

Maple hits both clamps. Sarasa and LXGW looked equally large despite the
model predicting Sarasa 5% smaller: glyph outlines matter too. CJK ink height
relative to Latin cap height measured 1.07× with Maple and 1.29× with the
larger fallbacks; below roughly 1.2× read as undersized in this comparison.
Using Sarasa Term SC as primary gave 0.5 em cells, unit scaling and 89% fill.

Vertical spacing measurements under Dank Mono:

| value | line box | 汉字 ink of it | |
|---|---|---|---|
| 15% | 55px | 67% | tuned for Latin alone, before any of this |
| **12%** | **54px** | **69%** | Dank Mono configuration |
| 8% | 52px | 71% | tried; Latin read cramped |

Coverage probes found Maple at 7% of `U+FF00-U+FFEF` and 0% of
`U+3400-U+4DBF`; missing glyphs reached Noto Serif CJK SC and PCMyungjo.
Sarasa and LXGW covered 91–100% of the mapped ranges. The measured Sarasa
bundle occupied 793 MB (480 faces, about 18% of the font directory); LXGW was
24 MB. Recheck disk usage when considering font-package cleanup.

### Reproducing size measurements

Use screenshot pixels: threshold a Retina capture and read ink runs by column
and row. CJK ink height against row pitch gives fill; Latin cap height
calibrates em (`0.650 × font-size × 2` for Dank Mono). Ratios survive an
unknown screenshot scale; absolute pixel counts do not. Re-measure after
changing the primary, fallback or cell metrics.

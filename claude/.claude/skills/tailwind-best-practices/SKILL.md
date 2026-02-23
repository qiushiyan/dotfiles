---
name: tailwind-best-practices
description: Tailwind CSS v4.1+ rules and best practices. Use when writing, reviewing, or refactoring Tailwind CSS code to ensure correct v4 utility usage and avoid deprecated patterns. Triggers on tasks involving Tailwind CSS classes, responsive design with Tailwind, or any HTML/JSX with Tailwind utility classes. Also use when reviewing PRs or code that contains Tailwind classes to catch deprecated v3 patterns.
---

# Tailwind CSS v4.1+ Best Practices

## Core Rules

- **Use Tailwind CSS v4.1+** - never use deprecated/removed utilities
- **Never use `@apply`** - use CSS variables, `--spacing()`, or framework components
- **Remove redundant classes** - audit breakpoint variants for duplicates
- **Use `min-h-dvh` not `min-h-screen`** - `min-h-screen` is buggy on mobile Safari
- **Use `size-*`** over separate `w-*`/`h-*` when dimensions are equal

## Removed Utilities (NEVER use in v4)

| Deprecated | Replacement |
|---|---|
| `bg-opacity-*` | `bg-black/50` (opacity modifier) |
| `text-opacity-*` | `text-black/50` |
| `border-opacity-*` | `border-black/50` |
| `divide-opacity-*` | `divide-black/50` |
| `ring-opacity-*` | `ring-black/50` |
| `placeholder-opacity-*` | `placeholder-black/50` |
| `flex-shrink-*` | `shrink-*` |
| `flex-grow-*` | `grow-*` |
| `overflow-ellipsis` | `text-ellipsis` |
| `decoration-slice` | `box-decoration-slice` |
| `decoration-clone` | `box-decoration-clone` |

## Renamed Utilities (ALWAYS use v4 name)

| v3 | v4 |
|---|---|
| `bg-gradient-*` | `bg-linear-*` |
| `shadow-sm` | `shadow-xs` |
| `shadow` | `shadow-sm` |
| `drop-shadow-sm` | `drop-shadow-xs` |
| `drop-shadow` | `drop-shadow-sm` |
| `blur-sm` | `blur-xs` |
| `blur` | `blur-sm` |
| `backdrop-blur-sm` | `backdrop-blur-xs` |
| `backdrop-blur` | `backdrop-blur-sm` |
| `rounded-sm` | `rounded-xs` |
| `rounded` | `rounded-sm` |
| `outline-none` | `outline-hidden` |
| `ring` | `ring-3` |

## Spacing

### Always use `gap` in flex/grid (never `space-x-*`/`space-y-*`)

```html
<!-- BAD -->
<div class="flex flex-wrap space-x-4">...</div>

<!-- GOOD -->
<div class="flex flex-wrap gap-4">...</div>
```

`space-*` adds margins to children and breaks with wrapped items. `gap` handles all cases correctly.

### General spacing

- Prefer top/left margins over bottom/right
- Use padding on parents instead of bottom margin on last child
- For max-widths, prefer container scale (`max-w-2xs` over `max-w-72`)

## Typography

### Always use line-height modifiers (never `leading-*`)

```html
<!-- BAD -->
<p class="text-base leading-7">...</p>
<p class="text-lg leading-relaxed">...</p>

<!-- GOOD -->
<p class="text-base/7">...</p>
<p class="text-lg/8">...</p>
```

Always use fixed line heights from the spacing scale, not named values.

### Font size reference

`text-xs`=12px, `text-sm`=14px, `text-base`=16px, `text-lg`=18px, `text-xl`=20px

## Opacity

Always use modifier syntax, never separate opacity utilities:

```html
<!-- BAD -->
<div class="bg-red-500 bg-opacity-60">...</div>

<!-- GOOD -->
<div class="bg-red-500/60">...</div>
```

## Responsive Design

Only add breakpoint variants when values actually change:

```html
<!-- BAD: redundant -->
<div class="px-4 md:px-4 lg:px-4">...</div>

<!-- GOOD: only specify changes -->
<div class="px-4 lg:px-8">...</div>
```

## Dark Mode

Light mode first, then `dark:` variants. `dark:` before other variants:

```html
<div class="bg-white dark:bg-black">
  <button class="hover:bg-gray-100 dark:hover:bg-gray-800">Click</button>
</div>
```

## Gradients (v4)

```html
<!-- GOOD: v4 gradient utilities -->
<div class="bg-linear-to-br from-violet-500 to-fuchsia-500"></div>
<div class="bg-radial-[at_50%_75%] from-sky-200 via-blue-400 to-indigo-900"></div>
<div class="bg-conic-180 from-indigo-600 via-indigo-50 to-indigo-600"></div>

<!-- BAD: deprecated -->
<div class="bg-gradient-to-br from-violet-500 to-fuchsia-500"></div>
```

## CSS Variables and Theme

### Accessing theme values

```css
.custom-element {
  background: var(--color-red-500);
  border-radius: var(--radius-lg);
}
```

### Spacing function

```css
.custom-class {
  margin-top: calc(100vh - --spacing(16));
}
```

### Extending theme

```css
@import "tailwindcss";

@theme {
  --color-mint-500: oklch(0.72 0.11 178);
}
```

## New v4 Features

### Container queries

```html
<article class="@container">
  <div class="flex flex-col @md:flex-row @lg:gap-8">
    <img class="w-full @md:w-48" />
    <div class="mt-4 @md:mt-0">...</div>
  </div>
</article>
```

### Text shadows (v4.1)

```html
<h1 class="text-shadow-lg">Large shadow</h1>
<p class="text-shadow-sm/50">Small shadow with opacity</p>
```

### Masking (v4.1)

```html
<div class="mask-t-from-50%">Top fade</div>
<div class="mask-b-from-20% mask-b-to-80%">Bottom gradient</div>
<div class="mask-radial-[100%_100%] mask-radial-from-75% mask-radial-at-left">Radial mask</div>
```

## Component Patterns

### Avoid utility inheritance on parents

```html
<!-- BAD: override on child -->
<div class="text-center">
  <h1>Centered</h1>
  <div class="text-left">Left</div>
</div>

<!-- GOOD: apply where needed -->
<div>
  <h1 class="text-center">Centered</h1>
  <div>Left</div>
</div>
```

### Extract repeated patterns into framework components, not CSS classes

### CSS nesting: only nest when parent has its own styles

```css
/* GOOD */
.card {
  padding: --spacing(4);
  > .card-title { font-weight: bold; }
}

/* BAD: empty parent */
ul {
  > li { /* parent has no styles */ }
}
```

## Common Pitfalls Checklist

1. Old opacity utilities - use `/opacity` syntax
2. Redundant breakpoint classes - only specify changes
3. `space-*` in flex/grid - use `gap`
4. `leading-*` classes - use line-height modifiers like `text-sm/6`
5. `@apply` - use components or CSS variables
6. `min-h-screen` - use `min-h-dvh`
7. Separate `w-*`/`h-*` for equal dims - use `size-*`
8. Arbitrary values like `ml-[16px]` - use scale (`ml-4`)
9. `bg-gradient-*` - use `bg-linear-*`

---
name: doc-writer
description: Guide for creating effective technical documentation. Use when writing, reviewing, or updating documentation files (*.md in docs/). Triggers on tasks involving README files, feature documentation, API docs, or when user asks to document a feature or system.
---

# Technical Documentation Guide

Write documentation for senior engineers navigating a codebase. Focus on mental models and design decisions, not implementation details.

## Core Philosophy

**Document the "what" and "why", link to the "how".**

- Establish context early: where does this feature fit in the app's architecture?
- Explain design decisions and tradeoffs, not just what the code does
- Link to source files instead of duplicating code
- Assume readers can read code—help them find the right files

## Docs Directory Structure

```
docs/
├── README.md                    # Project overview, links to all docs
├── auth.md                      # Single-file feature docs
├── api.md
│
├── payments/                    # Multi-file feature with sub-topics
│   ├── README.md                # Overview, shared concepts (e.g., idempotency)
│   ├── checkout.md
│   ├── subscriptions.md
│   └── webhooks.md
│
├── notifications/               # Complex feature with multiple concerns
│   ├── README.md                # High-level overview
│   └── email-templates.md       # Deep-dive on specific subsystem
│
└── ui-components/               # Shared components
    ├── README.md                # Registration, conventions
    └── data-table.md            # Per-component docs
```

**When to use folders vs single files:**
- **Single file**: Self-contained feature, <200 lines
- **Folder with README**: Feature has sub-topics or shared concepts
- **README.md in folder**: Overview + links to detailed docs; shared patterns go here

## Structure

### Opening

Start with a one-sentence description that answers: "What is this and what problem does it solve?"

```markdown
# Payment Processing

Handles checkout, subscription billing, and webhook events from Stripe.
```

Follow with context that places the feature in the broader system:

```markdown
**Integration:** Stripe API v2023-10

All payment state lives in Stripe; local DB stores only references for querying.
```

### Sections

Use descriptive titles that convey information, not abstract nouns.

| Avoid | Prefer |
|-------|--------|
| "Overview" | "How Authentication Works" |
| "Results" | "Webhook events persist to an audit log" |
| "Architecture" | "Data flows from Stripe webhooks to local DB" |

Common section patterns:

- **Data Flow** — Where data comes from, how it moves through the system
- **Design Decisions** — Why it works this way (named subsections for each decision)
- **State Management** — Core data structures with derived state table
- **Persistence** — What gets saved, table schemas, field descriptions
- **Files** — Table mapping files to purposes with links

### Code Examples

**Include code when it illustrates a design decision or non-obvious pattern.**

Link to source instead of copying full implementations. Use file trees with inline comments for directory overviews—more scannable than tables:

```markdown
## Files

src/features/payments/
├── checkout-form.tsx   # Form state, validation
├── use-checkout.ts     # Submission logic, error handling
├── stripe-client.ts    # Stripe SDK initialization
└── types.ts            # Shared types (CheckoutSession, PaymentIntent)
```

### Function Call Diagrams

**Include callstack diagrams for multi-step flows.** These help readers understand how functions connect without reading every file. Use arrows with brief comments explaining each step's purpose:

```markdown
## How Checkout Works

createCheckoutSession(cart)
  → validateCart(cart)            # Check stock, prices
  → calculateTotals(items)        # Subtotal, tax, shipping
  → stripe.checkout.create(...)   # Returns sessionId
  → saveOrderRecord(sessionId)    # Track in local DB
  → redirect(session.url)         # Send to Stripe hosted page
```

For data transformations, show input → output:

```markdown
## Webhook Payload Transformation

Stripe Event                     Internal Format
────────────────────────         ───────────────────
{ type: "checkout.session.completed" }  →  { orderId, status: "paid" }
{ type: "charge.refunded" }             →  { orderId, status: "refunded" }
```

For state flows, show the chain:

```markdown
## Auth State Flow

Cookie → SessionProvider (reads token)
      → React context (user object)
      → Components subscribe via useUser()

Login → setSession(token)
     → router.refresh()
     → Server re-renders with new user
```

**Key principle:** Include function names readers will grep for. The diagram should help them find the right file, not replace reading it.

### Architecture Diagrams

Use ASCII box diagrams for system overviews. Show component relationships and data flow:

```markdown
## Checkout Page Structure

┌─────────────────────────────────────────────────┐
│                    page.tsx                      │
│  (Server: auth, cart loading, price calculation)│
├─────────────────────────────────────────────────┤
│  ┌──────────────────┐                           │
│  │  CheckoutShell   │  (Client: form state)     │
│  │  ├─ CartSummary                              │
│  │  ├─ ShippingForm                             │
│  │  └─ PaymentForm  ──► Stripe Elements         │
│  └──────────────────┘                           │
└─────────────────────────────────────────────────┘
```

Keep diagrams focused—show one concept per diagram. If a diagram needs extensive explanation, it's too complex.

### Tables

Use tables for structured information:

- Field/column descriptions
- Configuration options
- State derivations
- API endpoints

Use file trees for directory overviews (more scannable than tables for file listings).

### Linking

**For listing multiple files**, use file trees with inline comments (see Files example above).

**For inline references** in prose, use backtick file paths (not markdown links—they're fragile):
- "See the validation logic in `src/features/payments/checkout.ts`"
- "**Schema**: `src/features/payments/types.ts` — CheckoutSession"

**For linking to other docs**, use markdown links: `See [webhook handling](./webhooks.md#verification)`

## Writing Style

**Find the middle ground.** Documentation should be concise but not skeletal. Include enough context that readers understand the flow without reading every source file.

**Cut filler, keep substance:**
- Remove: "In order to", "It should be noted that", "As mentioned above"
- Keep: Function names, parameter descriptions, return values, error conditions

**Use imperative/declarative voice:**
- "Users complete checkout" not "Checkout is completed by users"
- "The webhook handler validates signatures" not "Signatures are validated by the webhook handler"

**Put topic words first:**
- "Webhook events trigger background jobs" not "Background jobs are triggered by webhook events"

**Bold key terms** on first use or for emphasis in lists.

**Keep paragraphs short.** One idea per paragraph. Essential points get their own line.

**Include grepable names.** When describing a flow, use the actual function/component names so readers can find them:
- Good: "The `usePreviewMode()` hook reads from the Zustand store"
- Bad: "The hook reads from the store"

## What to Exclude

- Installation/setup instructions (assume dev environment exists)
- Migration guides (unless specifically requested)
- Future roadmap / TODO lists (belong in GitHub issues)
- Package dependency lists (visible in package.json)
- Step-by-step "how to add a new X" tutorials

**Verbose code blocks to avoid:**
- Full function implementations copied from source
- JSX showing basic component composition
- Error handling boilerplate

**Concise alternatives to keep:**
- Function signatures with parameter/return descriptions
- Callstack diagrams showing flow between functions
- Data transformation examples (input → output)
- State shape definitions

## README Files

For directory-level READMEs:

1. One-line description of what this module/feature does
2. Context: where it fits in the app
3. Table linking to detailed docs
4. Component/file structure diagram (if helpful)
5. Cross-references to related documentation

```markdown
# Payments

Checkout, subscriptions, and billing via Stripe integration.

## Features

| Feature | Description | Doc |
|---------|-------------|-----|
| [Checkout](./checkout.md) | One-time payments | Stripe Checkout |
| [Subscriptions](./subscriptions.md) | Recurring billing | Stripe Billing |
| [Webhooks](./webhooks.md) | Event handling | Signature verification |

## Key Files

src/features/payments/
├── checkout.ts       # Checkout session creation
├── subscriptions.ts  # Subscription management
├── webhooks.ts       # Event handlers
└── types.ts          # Shared types

## Related

- [Auth](../auth.md) — User identity for payment association
- [Notifications](../notifications/) — Payment confirmation emails
```

## Checklist

Before finalizing:

- [ ] Opening sentence answers "what is this?"
- [ ] Context establishes where this fits in the app
- [ ] Design decisions explained, not just described
- [ ] Multi-step flows have callstack diagrams with function names
- [ ] Function/component names are grepable (actual names, not "the hook")
- [ ] Source files referenced via file trees with inline comments
- [ ] Tables used for structured data (fields, options, endpoints)
- [ ] Section titles informative, not abstract
- [ ] No future/TODO sections (move to issues)
- [ ] No full implementations copied from source

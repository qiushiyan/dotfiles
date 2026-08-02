Use the `ctx7` CLI for current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — syntax, configuration, version migration, setup, CLI usage, or library-specific debugging. This covers well-known tools (React, Next.js, Django, …) and applies **even when you think you know the answer**; your training data may lag. Prefer it over web search for library docs.

Not for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. **Resolve** — `npx ctx7@latest library <name> "<question>"`. Required first, unless the user gave an ID in `/org/project` form.
2. **Pick the match** by name match, description relevance, snippet count, source reputation (prefer High/Medium), and benchmark score (higher is better).
3. **Fetch** — `npx ctx7@latest docs <libraryId> "<question>"`, then answer from what it returns.

Use the official name with real punctuation — "Next.js" not "nextjs", "Customer.io" not "customerio". If results look wrong, retry with an alternate name or a rephrased question. For a pinned version, use `/org/project/version` from the `library` output (e.g. `/vercel/next.js/v14.3.0`).

Pass the user's **full question** as the query — detailed beats vague single words. Never put secrets (API keys, passwords, credentials) in a query. Max 3 commands per question.

On a quota error, tell the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY`. Never silently fall back to training data.

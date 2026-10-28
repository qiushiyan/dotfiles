# Tools, large prompts, and the context window

Read this when the surface is a tool the model acts through (its name,
parameters, description, result, or error), a prompt built around large
material, or the design of what sits in the model's window. The general
rules are in [SKILL.md](SKILL.md).

## Tools

- Everything a tool shows is prompt. Build a few tools around whole
  workflows rather than wrapping an API. If an engineer cannot say which
  tool applies, the model cannot either.
- The description onboards a new teammate: query formats, terms, how
  resources relate. *When* to call the tool belongs in the system prompt.
  Use clear parameter names and enums that teach usage.
- Return readable fields over opaque ids. Keep bulky data the model need not
  read out of its path.
- An error names what stopped the call (the failing layer, or the rule and
  the state that failed it), what that implies, and the next action, with
  the cause in one line. It prescribes only what its path can
  prove: "written", not "all inputs validated" from a layer that cannot see
  validation.
- A result that changes what should happen next says so, with the reason.
  An action that is usually but not always wrong gets a warning once, then
  is allowed.
- Settle ergonomics by running realistic multi-call scenarios and reading
  what the agent fumbles.

## The context window

- A prompt around large material (documents, transcripts, data) opens on
  the task, places the material next, and asks the question last, since
  attention is weakest in the middle. Delimit the material so data is never
  read as instruction.
- Quality drops as the window fills, well before the limit. The common agent
  failure is the right information missing or buried, not clumsy wording.
- Hold references (paths, ids, queries) and load full content when needed.
  Disclose in tiers: an index first, the detail when the task matches.
- Keep the prefix stable so the cache hits it. Per-request content goes at
  the end.
- For work that outlives a window, keep state in files and tell the agent
  its context is managed, so it does not wrap up early.

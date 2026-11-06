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
- An error names the cause the model can act on (the failing layer, or the
  rule and the state that failed it), what that implies, including whether
  a retry can succeed, and the next action, with the cause in one line.
  When its trigger cannot tell two causes apart, it names both, and a line
  printed because a read failed claims only that the read failed. It
  prescribes only what its path can prove: "written", not "all inputs
  validated" from a layer that cannot see validation. A library's own
  message is advice to its developer: word the failure by its trigger, and
  keep that message as a labelled cause after the next step.
- A result that changes what should happen next says so, with the reason.
  An action that is usually but not always wrong gets a warning once, then
  is allowed.
- Settle ergonomics by running realistic multi-call scenarios and reading
  what the agent fumbles.

## Results and errors are read to the letter

The model does what a result says, edges included.

- **Every clause near a demand is part of it.** A reason beside a generic
  remedy changes the remedy, an umbrella word reads as the boundary of what
  it covers, and "any value" admits zero. Give each branch its own sentence
  by its trigger, and name each refused member. Where the generic remedy is
  itself wrong, print the right one in its place: no reason retracts a
  sentence printed after it.
- **A refusal is followed exactly.** It says where else the refused thing
  appears, such as the script that used it, offers no way round that
  switches the guard off, and suggests a replacement only from names with
  known meanings, never the nearest spelling.
- **A verb that is also a tool's name reads as a call.** Beside a tool named
  `ask`, write "tell the user", not "ask for".
- **An agent without a clock gets an order of work,** since it cannot wait
  30 seconds. Under load: carry on, try once more, then tell the user.
- **A step names only what its reader holds.** Name a command the reader
  has, and, where several roles or hosts read the same text, only what all
  of them deliver. For what only the user can change, name the setting they
  change, say to carry on with what the run has, and say the tool works
  again once it is changed.
- **A value the reader must use is one it will see.** The command prints it
  whatever a script does, and a source the user holds counts only if it
  carries the value.
- **Text read later states its facts at the event.** A queued message, a
  retried call's answer or a replayed question says what happened then, in
  the past tense, and nothing about now.
- **An outcome the tool cannot see stays open.** When an action may still
  land after its answer was lost, say what may not have happened, and leave
  a re-send to the user unless repeating it is harmless.
- **A message about a state holds for every way the state is reached,** so
  it promises only what each of those ways leaves true.
- **A result that says the host rewrote the model's text** names what
  changed, and asks for a re-read before an edit that must match it.
- **After an act the user approved, a note leads with that act's next
  steps,** and offers its inverse only for when the user wants it back.
- **Every outcome gets its line.** A silent success beside results that
  speak reads as doubt. A word a caller acts on, such as "saved", appears
  only in the line that gives that verdict.

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

# Skills, agent docs, and long-running agents

Read this when writing a skill, its description, a `CLAUDE.md` or
`AGENTS.md`, or instructions for an agent that works over many steps. The
stance is in [SKILL.md](SKILL.md).

## Where text sits

- **A pointer a reader has no reason to follow goes unread.** In our evals a
  companion file named only at the end was opened in 1 of 5 runs, and the
  example in it lost its effect. Inline what most runs need. Route to a
  companion from the opening, saying when to read it.
- **A context pointer** (a skill description, a `CLAUDE.md` line naming a
  doc) costs context every turn. Front-load its trigger, give one trigger per
  distinct case, and stop.
- **A leading word**, a concept the model already holds (*lesson*, *tight*,
  *red*), is repeated as a token, never as a sentence.
- **Split by sequence** only when later steps tempt the reader to rush the
  current one, and only across a real context boundary such as a subagent.

## Skill descriptions

A model-invoked skill's description sits in context every turn and decides
when the skill fires. Pick its shape by how past sessions reached the skill
(obelisk counts typed and model invocations):

- **The model reaches for it from the situation.** What it is in a few
  words, then `Use when` and each distinct situation in the user's words, in
  30 words at most: `Search past Claude Code and Codex sessions. Use when the
  user asks how something was done before, or to find a session.`
- **The user names its job in a sentence** ("run a consult with codex").
  What it is, and the phrase: `Second opinions from fresh codex or claude
  sessions. Use when the user asks for a consult.` Other skills can then
  call it too.
- **The user types it.** Set `disable-model-invocation: true`. The model
  never sees the description then, so it is a menu label of 10 words at
  most; Codex requires the field, so keep the label. The argument shape goes
  in `argument-hint`, as one bracketed line.

Leave out how the skill works, its internal terms, and `allowed-tools`. The
invocation choice and router skills: `../writing-for-agents/SKILL-MECHANICS.md`.
House shape, `skillOverrides`, and installing: `docs/agent-skills.md` in the
dotfiles repo.

## Agents that work over many steps

- **The final report is the user's first look at the work.** Lead with the
  outcome and the one or two things you need from them, without the
  vocabulary built while working. Say what is verified against a tool
  result and what is not.
- **Pause only where the work needs the user:** an irreversible action, a
  real change of scope, or input only they hold. When the user is thinking
  aloud, the deliverable is the assessment; otherwise act until done or
  blocked. Where ending the turn waits for no one, as in a pipeline, name
  the host's way to pause.

# Skills, agent docs, and long-running agents

Read this when writing a skill, its description, a `CLAUDE.md` or
`AGENTS.md`, or instructions for an agent that works over many steps. The
general rules are in [SKILL.md](SKILL.md).

## Structure

- Inline what every run needs. Put what only some runs reach behind a
  pointer one level deep.
- A **context pointer** (a skill description, a `CLAUDE.md` line naming a
  doc) costs context every turn. Front-load its trigger. Give one trigger
  per distinct case, and stop there.
- Repeat a **leading word**, a concept the model already holds (*lesson*,
  *tight*, *red*), as a token, never as a sentence.
- Split a document by sequence only when later steps tempt the reader to
  rush the current one, and only across a real context boundary such as a
  subagent. An inline split leaves the later steps in view.

## Skill descriptions

A model-invoked skill's description sits in context every turn and decides
when the skill fires. Pick its shape by how past sessions actually reached
the skill (obelisk can count typed and model invocations).

- **The model reaches for it from the situation.** What it is in a few
  words, then `Use when` and each distinct situation in the user's words.
  About 30 words at most: `Search past Claude Code and Codex sessions on
  both machines. Use when the user asks how something was done before, or to
  find a session.`
- **The user names its job in a sentence** ("run a consult with codex").
  What it is, and the phrase: `Second opinions from fresh codex or claude
  sessions. Use when the user asks for a consult.` Other skills can then
  call it too.
- **The user types it.** Set `disable-model-invocation: true`. The model
  never sees the description then, so it is a menu label of 10 words at
  most. Codex requires a `description`, so keep the label. The argument
  shape goes in `argument-hint`, as one bracketed line.

Leave out how the skill works and its internal terms; the body carries them.
Leave out `allowed-tools` (the usage lessons say why). The invocation choice
itself and router skills are in `../writing-for-agents/SKILL-MECHANICS.md`.
House shape, `skillOverrides`, and installing are in `docs/agent-skills.md`
in the dotfiles repo.

## Agents that work over many steps

Two policies belong in instructions for an agent that acts over many steps
or reports to someone who did not watch it work.

- **Re-ground the human.** A final report is the reader's first look at the
  work. Lead with the outcome, then the one or two things you need from
  them, explained as if new and without the vocabulary built while working.
  Check each claim against a tool result, and say what is verified and what
  is not.
- **Pause only where the work needs the user:** an irreversible action, a
  real change of scope, or input only they hold. When the user is thinking
  aloud, the deliverable is the assessment. Otherwise act, and end the turn
  when the work is done or blocked. Where ending the turn waits for no one,
  as in a pipeline, name the host's way to pause and what happens without
  it.

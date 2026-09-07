# Verify instructions with a cold reader

Use an independent reader for each materially different route the change
affects. Give it the files on disk and a concrete scenario, without your
interpretation or intended answer. Include enough raw evidence to make the
scenario answerable. Read-only simulation checks understanding; a runtime
trial needs its own authorization and evidence.

<example>
You are evaluating instructions from a fresh user's position. Read-only:
inspect the named files and relevant references; do not edit, query session
archives, or run the target engine.

Scenario: <the user's request and the minimum facts available to the agent>.
Entry point: <path to the skill or router on disk>.

Use the instructions to explain what you would do, what you could conclude,
what would require more evidence or user input, and when the task is complete.
Give exact commands only where the instructions promise an executable recipe.
Identify the first point where you would need to guess a path, field, flag,
or decision. Read references when the scenario requires them.

Then evaluate the result against
~/.claude/skills/prompt-engineering/SKILL.md. Report only supported defects,
ranked by their effect on this task: quote the relevant file and line, explain
the consequence, and suggest a minimal correction. Include unnecessary
instructions and missing routes when they affect the scenario. Verify any
claim that the repository contradicts the instructions before reporting it.
No defects is an acceptable result. Keep the report under 700 words.
</example>

Verify each finding against the files and the goal. A shared stall is strong
evidence for a repair; a proposed cut another reader relied on needs closer
inspection. Preserve rules that carry a real decision even if they look
redundant in isolation. After fixes, reread the affected route. Report what
this evaluation established without treating a planned sequence as a completed
execution or proof of improved runtime outcomes.

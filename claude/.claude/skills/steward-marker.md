# The steward's marker

A session started by the steward, or attached to one of its tasks with
`steward attach`, holds one step of a tracked task. The step ends when the
session writes its marker: one JSON file at the path `STEWARD_MARKER`
names. This file is the one home for the recipe; a skill that closes a
step points here and adds only its own outcome rule.

**Trigger.** `STEWARD_MARKER` is set in the environment. Read `STEWARD_ATTEMPT`,
`STEWARD_STEP` and `STEWARD_INPUT_REVISION` at the start of the session, since
the marker is accepted only when it names the step this session holds and
the revision it started from.

**Action.** At the close of the step, put the note in a quoted heredoc to a file
beside the marker (so an apostrophe, a quote, a backslash, a backtick or a `$` in
it is just text, and no `$(...)` is parsed around it, which macOS's bash 3.2 gets
wrong) and let `jq` encode the document; never assemble the JSON by hand:

```bash
cat > "$STEWARD_MARKER.note" <<'NOTE'
<one line: what this step produced and where>
NOTE
jq -n \
  --arg attempt "$STEWARD_ATTEMPT" --arg step "$STEWARD_STEP" --argjson inputRevision "$STEWARD_INPUT_REVISION" \
  --arg outcome advance --rawfile notes "$STEWARD_MARKER.note" \
  '{attempt: $attempt, step: $step, inputRevision: $inputRevision, outcome: $outcome, defaults: [], notes: ($notes | rtrimstr("\n"))}' \
  > "$STEWARD_MARKER"
```

- `outcome` is `advance` when the step is done, or `ask` when a person must
  answer before the next step; with `ask`, write the question the same way to
  `$STEWARD_MARKER.question`, pass it as `--rawfile question`, and add
  `question: ($question | rtrimstr("\n"))` to the object.
- `defaults` lists every question you decided alone, as
  `{"question": "<the question>", "taken": "<the default you took>"}`, so the
  ledger can judge the default later; build it with `--argjson defaults` from a
  `jq -n` of its own, and leave it `[]` when you decided nothing alone.
- `files` names every output file the step's prompt asks for, written beside
  the marker, each keyed by its name with its SHA-256 as the value; both doors
  a marker comes through verify each before the marker counts, so write the
  files first and the marker last. Leave it out when the step names none.
- A skill run inside a steward-driven build step never writes the marker: the
  step prompt names the outer session as its sole writer, and that session
  writes it once, at the end.
- A session attached from another machine submits the same bytes to the store
  with `ssh <host> steward marker submit < "$STEWARD_MARKER"`. The files the
  marker names are hashed on the host, beside the marker path `attach`
  printed: copy them there (`scp`) before submitting, or the door refuses the
  marker as naming files nobody wrote.

**Skip.** `STEWARD_MARKER` unset: nothing here applies, and the skill runs
exactly as it does today.

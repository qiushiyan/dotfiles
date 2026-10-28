# Dogfooding with a real bot

A change to `drive` or to this skill is tried end to end by a Grok bot that
drives by `BOT.md`: it runs a small batch of real Sonnet sessions in a
scratch repository, records each friction as it hits it, and reports where
the files and drive's messages failed it. A cold reader settles wording; this
settles what only a night of real turns shows: wakes, holds, the watchdog,
several runs acting at once, a report built after a reset. Done is an entry
in `EVIDENCE.md` with each finding placed in its layer and fixed or kept.

The bot is the Session Driver between its real drives, or a test bot set up
the same way. This runbook is for whoever runs the dogfood; the bot reads
only the brief and the files it names.

## Before the run

On the mini:

1. **The bot's own batch has nothing in flight.** A batch replaces only its
   own driver's last one, stopping that one's wakes: the Session Driver's
   dogfood replaces its real batch, while a test bot with a webhook of its
   own (`drive-session-test`) leaves every other driver's alone. `drive
   --driver session-driver status` shows what the Session Driver's batch
   still has open; run when it has nothing the owner is waiting on. The
   dogfood batch shows on the owner's page beside the others while it runs.
2. **The drive under test is installed** (`make install` in `~/dev/drive`):
   the bot runs `~/.local/bin/drive`.
3. **The bot's webhook file exists:** `~/.config/drive/webhooks/<webhook>`
   (`session-driver` for the Session Driver), mode 0600, `URL=` and `AUTH=`
   lines copied from its wake routine. The owner writes it; the bot never
   does.
4. **The scratch repository is ready:** `~/dev/scratch/drive-dogfood`, with no
   remote and no `twin` entry. `git -C ~/dev/scratch/drive-dogfood worktree
   list` shows what earlier runs left; the brief names it.

```bash
D=~/dev/scratch/drive-dogfood
[ -d "$D/.git" ] || { mkdir -p "$D" && git -C "$D" init -q && echo '# dogfood' > "$D/README.md" \
  && git -C "$D" add README.md && git -C "$D" commit -qm init; }
```

The Rex session `dogfood` keeps the run off `work`, where real sessions run;
`drive batch new` starts it if it is not running.

## The brief

Aim each run at what the last one left untested, which the newest
`EVIDENCE.md` entry names under **Next pass compares**. While the skill is
on an unmerged branch, the brief points at its worktree, and at that
branch's copy of any script it changed (`grokbot-transcript --archive`
exists only there until it merges).

```text
You are dogfooding <what changed> before <it reaches the live bot>. <What the last run left untested.> Drive a small batch end to end by the skill alone, then tell me where it failed you.

Read these in full at the start of every run, and trust them and drive's messages over what you remember of earlier runs:
- <skill dir>/BOT.md (you are the bot it describes)
- SKILL.md and NOTICE.md in the same folder
- <dotfiles checkout>/docs/session-pipeline.md

Your test world:
- Start a batch as BOT.md shows, named dogfood-<today>, in the Rex session `dogfood`, with `--webhook <webhook>` and "<bot name>" in the after-wake command. Use drive's default config, and write no webhook or config file.
- Open sessions in ~/dev/scratch/drive-dogfood on Sonnet, each with a small real task there, each first step stopping where its stage ends, so that the merge is a step you send.
- The repository has no remote and no twin entry. When you send a session its closeout, add after the snippet key that its finish is the local merge into main, with no push, PR or `twin`.
- <What earlier runs left in the repository, by name>: leave it alone.
- Choose the tasks so the run reaches <the patterns this run is for>. These are patterns, not a script; add what the files make you curious about.

Hard limits: act only on sessions you opened in `dogfood`. The `work` session holds my live sessions; leave every block there alone. Touch no repository but the scratch one: no pushes, no PRs, no edits to the skill or the tool. When a file or a message is wrong, keep going and record it.

Record each friction in the batch the moment you hit it (`drive record note`): a line you had to guess at, a `next:` that did not run as written or misled you, something you did by hand that the skill or the tool should have done for you.

When the batch is done, pause your watchdog and send one message with:
1. What worked as the files said.
2. Each place you guessed, quoting the line.
3. Each message that misled you, quoted, with what you did instead.
4. <What this run aimed at, such as who waited on whom for a hold and how it was freed, which wakes came and which `--due` posted again>, and what `drive metrics` says.
5. What you would change, as concrete wording.
```

Each fixed part of the brief guards a way a run went wrong:

- **A first step that names the finish is done at once.** Sessions told
  "your finish is a local merge" merged in their first turn, past review
  and the hold; the no-remote note rides on the closeout step instead.
- **The personal-tool closeout pushes and runs `twin sync`.** In a repository
  with neither, a session improvises (a `find ~` for twin's config became a
  runaway background job); the note after the snippet key keeps it local.
- **The bot's own webhook, in drive's default config.** Another bot's file
  wakes that bot, and the workaround a bot reaches for, a private
  `DRIVE_CONFIG_DIR`, holds settings that only the commands setting it read.
- **Patterns, not a script.** A listed case the files cannot reach shows up
  as the bot's guess, which is the finding; a script hides it.
- **A pattern that waits on drive's timing says how long.** A wake left
  unanswered is posted again only ten minutes on; a bot that acts sooner
  never sees the repost it was sent to test.

## Reading the result

The batch's record is the primary evidence: the bot's diagnosis of a
friction can be wrong, and its chat reaches the mini only as the Grok Bot
app syncs it, so its messages from an unattended run, the final report
among them, can be missing from `grokbot-transcript` and from the archive
alike.

```bash
B=dogfood-<today>
drive log --batch $B; drive metrics --batch $B
# the friction notes in full (times UTC)
jq -r 'select(.kind == "note" and (.note | startswith("after_wake") | not)) | "\(.at[11:16]) \(.session // "-") \(.note)"' \
  ~/.local/state/drive/batches/$B/events.jsonl
# each session's id, for its transcript and claude-steps show
jq -r 'select(.sid) | "\(.session) \(.sid)"' ~/.local/state/drive/batches/$B/events.jsonl | sort -u
grokbot-transcript "<bot name>"
```

`drive read <label> --batch $B` reads a closed session's transcript, recap
included. Check each friction against the record and the transcripts before
acting on it, then place it:

- **Engine:** a message that misled or a mechanism the bot worked around in
  prose goes to `drive`, with a test that goes red without the fix
  (`~/dev/drive/CLAUDE.md`); the skill then needs less text, not more.
- **Skill:** a judgment the bot lacked becomes one short line where that
  decision is made, with its reason.
- **The brief or the setup:** a run the brief sent wrong is fixed in the
  template above.
- **Rejected:** a proposal that patches the symptom, or that would weaken a
  rule that protects shared state (a send that frees a hold), is named with
  the reason it loses.

Record the run in `EVIDENCE.md`, newest first: its corpus, findings,
changes, and what the next run compares.

## After the run

The bot pauses its watchdog when the batch ends; an ask left open keeps it
running, since the watchdog rechecks open asks, so answer or moot it to end
the batch. Once its record is read, `drive --batch $B batch end` stops the
dogfood's wakes and takes it off the owner's page.
Worktrees a run leaves in the scratch repository stay until a brief names
them for cleanup.

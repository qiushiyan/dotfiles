# Telling the user, and keeping the record

Every driver writes to the user this way and keeps this record, whether it
is a chat bot (BOT.md) or a Claude Code session (SESSION.md). SKILL.md §
Report gives a report's sections; this file is how any message to the user
reads.

## The record

Record what drive cannot see as you decide it, the plan first, since a
driver that comes back after a reset or a compaction starts from the
record, not from what it remembers. A fact you remember, such as which
release production serves, is stale until a command shows it again.

**A park keeps the tab.** A parked session whose tab the user closes comes
back: the watchdog reports it gone, and its reopen restores it, still parked.
So close a wrapped-up session (`drive close`); park only one with a step to
come.

## The page

The user's page shows every driver's batch on the machine you run on, live:
each session's goal, where it stands, its PRs, its history with your notes
verbatim, and the questions waiting on the user. Every batch runs on Mini 2:
link the page as `https://qiushi-mini-2.tailf7adf1.ts.net:8444`
(`…:8444/#2026-11-06/summary-gate` for a session), never `qiushi-mini`.
Your messages carry what it cannot: what changed, why, and what you
recommend.

## Messages

- **One message per event:** a park on something only the user can give, a
  finish, a merge or release, a halt, the plan. Say what changed, then the
  sections SKILL.md § Report gives.
- **Plain words, times in GMT.** Send a result, never a note that you are
  checking or will report later.
- **Review bots.** Codex and Cursor out of quota is not a blocker and not
  worth reporting; rely on the in-session review and the strategic review.
- **A stop that needs the user** is written for the user as they read it: on
  their phone or at the terminal, hours later, remembering the product, the customers and the
  people but not the session, its vocabulary, its tickets, its finding
  numbers or what it tried. It opens on the session's goal and says what each
  option changes for the people using the product, or that nobody would
  notice. Here is a stop written in the session's terms, and the same stop
  written for the user:

  <example type="avoid">
  **Summary gate's re-run release gate failed, so it's parked until you answer two questions.** Summary gate is the summariser release-gate session, with the bench card on QIU-295 and #9539.

  **Rules, A22.** Summary gate re-judged every summary blind using your definition of a planner rule.
  - **On Haiku:** the branch beats develop on four of the five readings. The one it loses is the since-10-22 window, where invented content rises from 3.42 to 4.08 per summary. Most of that is a skill's own rules being copied in as "hard constraints".
  - **Rules the branch drops but develop keeps:**
    - "Keep the OPC browse focused" was dropped in 2 of 3 replays, after the browse had finished.
    - "Stop at the first failure" was dropped in 1 of 3 replays.
    - A pacing rule held through fold 7, then was dropped at fold 8.
  - **On Sonnet:** it invents less, about one item per summary, but drops three rules in every replay.
  - **The options:**
    - **A (recommended):** carry rules forward in code, and drop one only when the summariser marks it lifted. That fixes rules lost at a later fold, like the pacing rule, but not a rule missed at a thread's first fold.
    - **B:** another prompt pass. The pass just done didn't stop the drops.
  - **A side question:** does "keep the browse focused" still hold once the browse is done? Your definition, "holds while that work runs", suggests it doesn't. If so, dropping it isn't a failure.

  **Commits, A23.** Committed schedules went missing on one long thread, and develop loses them too. A script had trimmed the save output to bare `scheduleId=` lines, so the code can't see those commits. Until session 2's commit receipt (QIU-298) lands, Summary gate recommends that the strict "no lost commits" rule cover only commits the code can see. Commits it can't see, like those saves, would count only toward the totals. Yes or no?

  **Where Summary gate is:** it has four new local commits, the last `f85ff0fa1b6`. They're not pushed. All suites pass and the type checks are clean. Codex's third review round fixed two medium defects:
  - an incomplete set of readings could still show the gate as passed;
  - unsaved work could hide a dropped commit.

  There's no PR yet. The comparison pairs are in `scratchpad/gate/pairs2/pairs.html` and the scores in `scratchpad/gate/scores2/gate.txt`, both in Summary gate's scratchpad on the mini.
  </example>

  <example>
  **Summary gate's goal:** decide whether the new summariser is good enough to replace develop's. The summariser keeps a running summary of long Loopy conversations, so the planner remembers what matters after older messages are trimmed.

  **Where it stands:** after your 1B and 2B answers, Summary gate tightened the prompt on what counts as a planner rule and re-ran the comparison. A blind judge scored every summary from the new version and from develop. The new version still didn't clear the bar, so Summary gate has stopped. Nothing is pushed and there's no PR yet.

  **What went wrong, in plain terms:**
  - **Dropped instructions:** the new summariser sometimes forgets standing instructions the planner gave, like "stop at the first failure", which develop keeps. A pacing rule survived seven summary updates and was dropped at the eighth.
  - **Made-up rules:** in the newest conversation window, it writes in rules nobody gave. These are mostly a skill's own rules copied in as if the planner had said them.
  - **Sonnet doesn't fix it:** Sonnet makes up less but forgets more.

  **Decision 1, how to stop dropped rules (A22):**
  - **A, recommended:** code carries every rule forward on each update, and a rule is removed only when the summariser explicitly marks it as finished. People in long Loopy chats stop seeing the planner forget what they told it earlier. A rule the summariser misses the first time it summarises still wouldn't be caught.
  - **B:** another round of prompt tuning. The round just done didn't stop the drops, so people may keep seeing the planner forget.

  **Decision 1b, a side question:** "keep the OPC browse focused" was dropped after the browse had finished. By your own definition, a rule holds while that work runs. If the rule ends with the browse, that drop is correct and not a failure, and the results look better.

  **Decision 2, lost commits (A23):** the gate has a hard rule that no saved schedule may be lost from the summary. On one long thread, saves went missing in develop too, because a script had trimmed the save output so the code can't see those saves at all. Summary gate suggests that until the save receipts another session is building land, the hard rule covers only saves the code can see. The invisible ones would still count in the totals but couldn't fail the gate on their own. Nobody using Loopy would notice: it changes only what fails the gate.

  Meanwhile Summary gate builds A as recommended, and nothing ships until you answer. The card from last night has all three. I'd go with A, "the browse rule ends with the browse", and yes on A23.
  </example>
- **A message about one session** states its goal as `drive read` prints
  it, so your message and the page agree, and links its card by its batch and
  label (`…:8444/#2026-10-23/summary-gate`).
- **When the user asks for an outline** of where things stand, send the
  page and add what it cannot show, from `drive status`, the record and the
  sessions: what comes next for each, and anything holding the batch that
  drive does not track, such as a release pause.
- **Bench cards** (`QIU-…`) live outside the Linear connector, in the user's
  personal workspace: have a session change them with the `bench` CLI.
- **A message for another person** goes to the user as a draft. A reply to
  Felix belongs in the matching thread of the user's DM with Felix.

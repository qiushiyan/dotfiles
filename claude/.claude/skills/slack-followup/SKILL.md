---
name: slack-followup
description: "Reply in Slack as Qiushi, or close an item his Slack digest tracks, with the slack-digest CLI — when work someone in Slack is waiting on has landed (\"tell Dana it's fixed\", \"let them know it's merged\"), when he asks what Slack still needs from him, or to read the thread behind a digest item."
---

# Follow up on Slack with `slack-digest`

Qiushi's morning Slack digest keeps a ledger of what each of his workspaces
still needs from him: requests, promises, unanswered questions. Each item
has a short id, the thread it lives in, and often a drafted reply. Most
answers are owed after work lands, in a session like this one, so this
skill closes that loop: find the item, read its thread, post the reply as
him, and close it. It is done when the reply he approved is in the thread
and the item is closed, or kept open on purpose.

```sh
slack-digest items                        # open items: id, workspace, title, why, drafted reply
slack-digest items --workspace acme
slack-digest show 3f9a                    # one item and its thread as it stands now
slack-digest reply 3f9a                   # preview: the text, and where it would go
slack-digest reply 3f9a "The lost edits when typing fast are fixed (web#412)." --send
slack-digest reply 3f9a --send --keep     # post the draft, leave the item open
slack-digest done 3f9a "fixed in web#412" # close without replying
```

## Sending

A reply goes out under Qiushi's name to a colleague, so show him the
preview and send only after he says yes to that text; an edit he asks for
goes in as the text argument. Read the thread with `show` first when the
draft is older than the work you just did: the question may have moved on,
or someone else may have answered.

Write as he would: English, his voice, two sentences at most, naming the PR
or change that settles it. Say "merged" when it is merged and "live" only
when it is deployed where they use it.

`reply --send` closes the item with a link to the reply. Use `--keep` when
the reply answers only part of what was asked, and `done` or `ignore` for an
item that needs no reply.

## What to expect

- The ledger lives on another machine; the commands reach it over ssh on
  their own, so a call takes a few seconds and fails when that machine is
  unreachable.
- An id is the first characters of the item's id; a prefix matching two
  items is an error asking for more characters.
- Only items the digest tracks are here. A thread it never raised is not in
  the ledger; read or answer that one in Slack.

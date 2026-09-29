---
name: slack-followup
description: "Reply in Slack as Qiushi, or close an item his Slack digest tracks, through the slack-digest CLI — when work someone in Slack waits on has landed (\"tell Dana it's fixed\"), when he asks what Slack still needs from him, or to read a digest item's thread."
---

# Follow up on Slack with `slack-digest`

Qiushi's morning Slack digest keeps what each workspace still needs from
him — requests, promises, unanswered questions — as open items, each with a
short id, its thread, and often a drafted reply. The answer usually comes
due after the work lands, in a session like this one. You are done when the
reply he approved is in the thread and the item is closed, or kept open on
purpose.

```sh
slack-digest items               # open items, with ids and drafted replies
slack-digest show 3f9a           # the item and its thread as it stands now
slack-digest reply 3f9a          # preview: the text, and where it would go
slack-digest reply 3f9a "The lost edits when typing fast are fixed (web#412)." --send
```

`slack-digest items -h` covers the rest: `--keep`, `--workspace`, `done`
and `ignore`.

## Sending

The reply goes out under Qiushi's name, so show him the preview and send
only once he says yes to that text. Read the thread with `show` first: the
question may have moved on, or someone may have answered it already.

Write as he would: English, two sentences at most, naming the PR or change
that settles it. Say "live" only when it is deployed where they use it, and
"merged" until then.

Sending closes the item with a link to the reply. Use `--keep` when the
reply answers only part of what was asked, and `done` or `ignore` for an
item that needs no reply. Only threads the digest raised are here; a
follow-up anywhere else is his to post in Slack.

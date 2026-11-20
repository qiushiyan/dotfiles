# A browser signed in to the lane

`agent-browser` drives a real Chrome. The lane mints a session of its own for
you, sent as a header, so you never touch the owner's cookies.

**It cannot show** the deployed build or production data, and a person's
judgment of a design: that is the owner's, from your screenshots.

## Signed in

```bash
cd application
AB=$(pnpm run -s lane session | jq -r .agentBrowser)   # agent-browser --session lane-<n> --headers '{"X-PL-Session":…}' open <origin>/app
eval "$AB"
```

Later commands name the same `--session lane-<n>`; the header carried by the
first `open` keeps the browser signed in. Take the app's address from
`lane status` rather than guessing a port: `.app.url` already ends in `/app`.

```bash
B="agent-browser --session lane-<n>"; APP=$(pnpm run -s lane status | jq -r .app.url)
$B open "$APP?ws=s-<purpose>"
$B open "$APP?ws=s-<purpose>&chat=true&aithread=<thread id>"   # a Loopy thread, chat open
$B wait --text "<text the page shows when ready>"
$B snapshot -i -c                      # what is on the page, with refs to click
$B screenshot <scratchpad>/<name>.png  # evidence the report can name
$B set viewport 390 844                # a phone width
$B close                               # at teardown
```

A Loopy thread to open: drive one with `planlab --lane . loopy` first (lane
patterns); its result block names the thread.

## What to look at

The states nobody tried: empty, long content, a narrow width, a reload in
the middle, a second tab, the feature switch on and off, the same screen on
the baseline lane. For a change in how something looks, put the screenshots
in the report: the design call is the owner's.

## Keep to the lane's session

The lane's own browser session keeps the owner signed in: the cookie is
shared across `localhost` ports, so the owner's profile, or a QA
container's app opened in the same browser, signs the worktrees out. A
deployed copy (the PR's `preview` label) costs money while it runs, so it is
the owner's call.

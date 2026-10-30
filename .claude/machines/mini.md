You are on the mini: the office Mac mini (`qiushi-mini`, user `qiushiyan`,
home `/Users/qiushiyan`), headless compute.

- **This checkout is a clone, and so are the mac's and mini2's.** No machine
  is a copy of another: edit, commit and push here like anywhere. A commit
  made here is on another machine only once it is pushed and pulled there,
  and the same the other way; pull first when the `twin` lines below show
  this checkout behind (`twin repos pull dotfiles`).
- **Activation is each machine's own.** A pull does not restow, render the
  Codex config or load a launchd agent: `twin dotfiles apply` does, here.
  This machine stows the packages `twin/.config/twin/twin.toml` lists for
  it, which is not every package in the tree, and builds its own CLIs
  (`twin tools install`).
- **This machine is `twin`'s hub.** Gitignored files the manifest lists
  pass through it, on its hourly `twin tick` or a `twin files sync` given
  on any machine, so they move only while it is up.
- **The mac is the MacBook Pro**, which the docs call the laptop (`ssh mac`,
  when it is awake). **mini2** (`ssh mini2`) is the second office Mac mini,
  the office workstation with the monitor: `docs/qiushi-mini-2.md`.
- **What to run when, across the machines:** `docs/twin.md`.

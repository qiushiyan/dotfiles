You are on the mini: the office Mac mini (`qiushi-mini`, user `qiushiyan`,
home `/Users/qiushiyan`).

- **This checkout is a clone, and so is the mac's.** Neither machine is a
  copy of the other: edit, commit and push here like anywhere. A commit made
  here is on the mac only once it is pushed and pulled there, and the same
  the other way; pull first when the `twin` lines below show this checkout
  behind (`twin repos pull dotfiles`).
- **Activation is each machine's own.** A pull does not restow, render the
  Codex config or load a launchd agent: `twin dotfiles apply` does, here.
  This machine stows the packages `twin/.config/twin/twin.toml` lists for
  it, which is not every package in the tree, and builds its own CLIs
  (`twin tools install`).
- **The mac is the MacBook Pro**, which the docs call the laptop
  (`ssh mac`, when it is awake). It runs the reconciler: gitignored files
  the manifest lists move between the two only while it is awake, and a
  `twin files` command given here is handed to it.
- **What to run when, across the laptop and the mini:** `docs/twin.md`.

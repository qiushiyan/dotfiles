You are on mini2: the second office Mac mini (`qiushi-mini-2`, user
`qiushiyan`, home `/Users/qiushiyan`), the office workstation with the
monitor.

- **This checkout is a clone, like the laptop's and the mini's.** A commit
  made here is elsewhere only once it is pushed and pulled there; pull first
  when the `twin` lines below show this checkout behind
  (`twin repos pull dotfiles`).
- **Activation is each machine's own.** A pull does not restow or render the
  Codex config: `twin dotfiles apply` does, here, and `twin sync` does it on
  every machine whose checkout it moved. A new launchd agent loads only with
  `twin dotfiles apply --load-agents`, on the machine that runs it.
  This machine stows the Makefile's default set, as the laptop does, and
  builds its own CLIs (`twin tools install`).
- **The mini** (`ssh mini`, `qiushi-mini`) is the first office Mac mini:
  headless compute, and `twin`'s hub. Gitignored files the manifest lists
  pass through it, so they move only while it is up; a `twin files`
  command given here is handed to it.
- **The laptop is `ssh mac`** (the MacBook Pro), when it is awake.
- **What to run when, across the machines:** `docs/twin.md`.

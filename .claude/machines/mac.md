You are on the mac: the MacBook Pro (user `qiushi`, home `/Users/qiushi`),
which the docs call the laptop.

- **This checkout is a clone, and so are the minis'.** No machine is a copy
  of another. A commit made here is on another machine only once it is
  pushed and pulled there, and the same the other way; pull first when the
  `twin` lines below show this checkout behind (`twin repos pull dotfiles`).
- **Activation is each machine's own.** A pull does not restow or render the
  Codex config: `twin dotfiles apply` does, here, and `twin sync` does it on
  every machine whose checkout it moved. A new launchd agent loads only with
  `twin dotfiles apply --load-agents`, on the machine that runs it. The packages each machine stows and
  the files `twin` carries between them are listed in
  `twin/.config/twin/twin.toml`.
- **The mini is the office Mac mini** (`ssh mini`), headless compute, and
  `twin`'s hub: gitignored files the manifest lists move only while it is
  up, on its hourly `twin tick` or a `twin files sync`, which this machine
  hands to it.
- **mini2 is the second office Mac mini** (`ssh mini2`), the office
  workstation with the monitor: `docs/qiushi-mini-2.md`.
- **What to run when, across the machines:** `docs/twin.md`.

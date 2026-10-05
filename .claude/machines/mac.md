You are on the mac: the MacBook Pro (user `qiushi`, home `/Users/qiushi`),
which the docs call the laptop.

- **This checkout is a clone, and so is the mini's.** Neither machine is a
  copy of the other. A commit made here is on the mini only once it is pushed
  and pulled there, and the same the other way; pull first when the `twin`
  lines below show this checkout behind (`twin repos pull dotfiles`).
- **Activation is each machine's own.** A pull does not restow, render the
  Codex config or load a launchd agent: `twin dotfiles apply` does, here, and
  nothing runs it for the mini. The packages each machine stows and the files
  `twin` carries between them are listed in `twin/.config/twin/twin.toml`.
- **The mini is the office Mac mini** (`ssh mini`). This machine runs the
  reconciler: gitignored files the manifest lists move between the two only
  while it is awake, on its hourly `twin tick` or a `twin files sync`.
- **What to run when, across the laptop and the mini:** `docs/twin.md`.

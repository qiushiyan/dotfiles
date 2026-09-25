local paths = require("config.paths")
require("custom.floating-todo").setup({
  global_file = paths.todo_file,
})

require("custom.fold-markdown-headings").setup()
require("custom.inline-math").setup()

-- reply reference beside Claude Code's Ctrl+G prompt buffers; registered here,
-- not in VeryLazy autocmds, so it sees the startup buffer
require("claude-prompt").setup()

local paths = require("config.paths")
require("custom.floating-todo").setup({
  global_file = paths.todo_file,
})

require("custom.fold-markdown-headings").setup()
require("custom.inline-math").setup()

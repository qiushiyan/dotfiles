-- Claude Code's Ctrl+G prompt buffers: the one test for "is this a prompt
-- file", shared by skill completion, the reply reference window, and the
-- tmux path-copy exclusion in config/autocmds.lua.

local M = {}

-- <base>/claude-<uid>/claude-prompt-<id>.md (docs/claude-prompt-completion.md),
-- anchored on the parent dir so ordinary files named claude-prompt-*.md don't
-- count.
function M.is_prompt_file(path)
  return path:find("/claude%-[^/]+/claude%-prompt%-[^/]*$") ~= nil
end

function M.setup()
  require("claude-prompt.reference").setup()
end

return M

-- fff has no Lua/Rust knob to disable its .gitignore filtering -- the
-- ignore::WalkBuilder flags are hardcoded in crates/fff-core/src/file_picker.rs.
-- The only documented override is per-project `.ignore` files, which take
-- precedence over `.gitignore`. This helper drops a small template at the git
-- root on first picker invocation so files like .env stay visible.
-- `.ignore` is in our global gitignore so it never gets committed.
local function ensure_unignore_visible()
  local root = vim.fs.root(0, ".git")
  if not root then
    return
  end
  local path = root .. "/.ignore"
  if vim.fn.filereadable(path) == 1 then
    return
  end
  pcall(vim.fn.writefile, {
    "# fff.nvim: re-include files that .gitignore would hide.",
    "# Managed by nvim/lua/plugins/fff.lua. Add more `!pattern` lines as needed.",
    "!.env",
    "!.env.*",
  }, path)
end

return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {
    -- Defaults are sensible: centered 0.8x0.8, preview on the right, prompt
    -- at bottom, frecency on, .gitignore respected, starts in insert mode.
  },
  keys = {
    {
      "<leader><space>",
      function()
        ensure_unignore_visible()
        require("fff").find_files()
      end,
      desc = "Find files (fff)",
    },
    {
      "<leader>/",
      function()
        ensure_unignore_visible()
        require("fff").live_grep()
      end,
      desc = "Live grep (fff)",
    },
    {
      "<leader>sw",
      function()
        ensure_unignore_visible()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "Grep word under cursor (fff)",
      mode = "n",
    },
    {
      "<leader>sz",
      function()
        ensure_unignore_visible()
        require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } })
      end,
      desc = "Fuzzy grep (fff)",
    },
  },
}

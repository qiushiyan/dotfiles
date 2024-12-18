local function pre_save()
  local cwd = vim.fn.getcwd() .. "/"
  -- remove buffers whose files are located outside of cwd
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufpath = vim.api.nvim_buf_get_name(buf) .. "/"
    if not bufpath:match("^" .. vim.pesc(cwd)) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

-- disabled now because it overwrites neo-tree window settings
return {
  {
    "folke/persistence.nvim",
    enabled = false,
    ---@module "persistence.nvim"
    ---@type Persistence.Config
    opts = {
      pre_save = pre_save,
    },
  },
  {
    "rmagatti/auto-session",
    lazy = false,
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { "~/", "~/workspace", "~/Downloads", "/" },
      -- log_level = 'debug',
      no_restore_cmds = {
        "Neotree show",
      },

      -- called after a session is restored
      post_restore_cmds = {
        "Neotree show",
      },
    },
  },
}

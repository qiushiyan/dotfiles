local function pre_save()
  local cwd = vim.fn.getcwd() .. "/"
  -- remove buffers whose files are located outside of cwd
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufpath = vim.api.nvim_buf_get_name(buf) .. "/"
    if not bufpath:match("^" .. vim.pesc(cwd)) then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

-- disabled now because it overwrites neo-tree window settings
return {
  {
    "folke/persistence.nvim",
    ---@module "persistence.nvim"
    ---@type Persistence.Config
    opts = {
      pre_save = pre_save,
    },
  },
}

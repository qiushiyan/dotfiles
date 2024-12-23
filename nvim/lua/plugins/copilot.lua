return {
  {
    "zbirenbaum/copilot.lua",
    suggestion = {
      enabled = not vim.g.ai_cmp,
      keymap = {
        accept = "<M-l>",
        prev = "<M-[>",
        next = "<M-]>",
        dismiss = "<C-]>",
      },
    },
    panel = { enabled = false },
  },
  {
    "nvim-cmp",
    enabled = true,
  },
}

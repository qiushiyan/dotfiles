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
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      window = {
        width = 0.5,
        border = "rounded",
      },
    },
  },
}

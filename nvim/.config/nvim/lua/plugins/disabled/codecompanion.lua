return {
  "olimorris/codecompanion.nvim",
  enabled = false,
  config = true,
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "MeanderingProgrammer/render-markdown.nvim",
    "zbirenbaum/copilot.lua", -- Optional: For using slash commands and variables in the chat buffer
    "saghen/blink.cmp",
    { "stevearc/dressing.nvim", opts = {} },
  }, -- Optional: Improves `vim.ui.select`
  keys = {
    {
      "<leader>sa",
      "<cmd>CodeCompanionActions<cr>",
      noremap = true,
      silent = true,
      desc = "[S]earch Code Companion [A]ctions",
    },
    {
      "<leader>ct",
      "<cmd>CodeCompanionChat Toggle<cr>",
      noremap = true,
      desc = "Code Companion [C]hat [T]oggle",
    },
    {
      "<leader>aa",
      "<cmd>CodeCompanionChat<cr>",
      mode = "v",
      noremap = true,
      desc = "Code Companion [C]hat [T]oggle",
    },
    {
      "<leader>ae",
      "<cmd>CodeCompanion /explain<cr>",
      mode = "v",
      noremap = true,
      silent = true,
      desc = "[C]ode Companion [E]xplain",
    },
    {
      "<leader>cc",
      "<cmd>CodeCompanion<cr>",
      mode = { "n", "v" },
      noremap = true,
      desc = "Launch [C]ode [C]ompanion",
    },
  },
  opts = {
    display = {
      action_palette = {
        width = 95,
        height = 10,
        prompt = "Prompt ", -- Prompt used for interactive LLM calls
        provider = "default", -- default|telescope|mini_pick
        opts = {
          show_default_actions = true, -- Show the default actions in the action palette?
          show_default_prompt_library = true, -- Show the default prompt library in the action palette?
        },
      },
    },
    strategies = {
      chat = {
        adapter = "qwen",
      },
      inline = {
        adapter = "qwen",
      },
      agent = {
        adapter = "qwen",
      },
    },
    adapters = {
      qwen = function()
        return require("codecompanion.adapters").extend("ollama", {
          name = "qwen", -- Give this adapter a different name to differentiate it from the default ollama adapter
          schema = {
            model = {
              default = "qwen2.5-coder:32b",
            },
          },
        })
      end,
    },
  },
}

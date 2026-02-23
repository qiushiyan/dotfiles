return {
  "yetone/avante.nvim",
  enabled = false,
  event = "VeryLazy",
  lazy = false,
  version = false,
  opts = {
    -- add any opts here
    -- for example
    -- provider = "claude",
    -- auto_suggestions_provider = "claude",
    -- cursor_applying_provider = nil, -- The provider used in the applying phase of Cursor Planning Mode, defaults to nil, when nil uses Config.provider as the provider for the applying phase
    -- claude = {
    --   endpoint = "https://api.anthropic.com",
    --   model = "claude-3-7-sonnet-20250219",
    --   temperature = 0,
    --   max_tokens = 4096,
    -- },
    --
    provider = "ollama",
    ollama = {
      endpoint = "http://127.0.0.1:11434", -- Note that there is no /v1 at the end.
      model = "qwen2.5-coder:32b",
    },
    windows = {
      width = 50,
    },
    behaviour = {
      -- enable_claude_text_editor_tool_mode = true,
    },
    -- system_prompt = function()
    --   local hub = require("mcphub").get_hub_instance()
    --   return hub:get_active_servers_prompt()
    -- end,
    -- The custom_tools type supports both a list and a function that returns a list. Using a function here prevents requiring mcphub before it's loaded
    -- custom_tools = function()
    --   return {
    --     require("mcphub.extensions.avante").mcp_tool(),
    --   }
    -- end,
    -- disabled_tools = {
    --   "list_files",
    --   "search_files",
    --   "read_file",
    --   "create_file",
    --   "rename_file",
    --   "delete_file",
    --   "create_dir",
    --   "rename_dir",
    --   "delete_dir",
    --   "bash",
    -- },
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "ravitemer/mcphub.nvim",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "nvim-mini/mini.icons",
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}

return {
  "ravitemer/mcphub.nvim",
  enabled = false,
  opts = {
    extensions = {
      avante = {},
    },
  },
  auto_approve = true,
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
  },
  -- comment the following line to ensure hub will be ready at the earliest
  cmd = "MCPHub", -- lazy load by default
  build = "pnpm install -g mcp-hub@latest", -- Installs required mcp-hub npm module
  -- uncomment this if you don't want mcp-hub to be available globally or can't use -g
  -- build = "bundled_build.lua",  -- Use this and set use_bundled_binary = true in opts  (see Advanced configuration)
  config = function()
    require("mcphub").setup()
  end,
}

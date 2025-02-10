return {
  "folke/noice.nvim",
  -- Classic commandline position instead of pop-up
  opts = {
    routes = {
      { filter = { event = "msg_show", find = "search hit" }, skip = true },
    },
    cmdline = {
      -- view = "cmdline", -- moves command line to bottom
    },
    -- presets = { command_palette = false }, -- tab completions for commandline don't pop-up at top
  },
}

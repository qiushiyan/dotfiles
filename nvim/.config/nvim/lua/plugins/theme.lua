-- Colorscheme plugins for each terminal theme. All are installed (the active one
-- eager, the rest lazy) so the live-swap watcher can switch in any direction.
-- See docs/theming.md.

local theme = require("config.theme")

return {
  {
    "folke/tokyonight.nvim",
    -- Same pattern as catppuccin: always installed so the live-theme watcher can
    -- swap to it, eager only when active. "moon" is the variant the
    -- tokyo_night_moon terminal theme maps to (colorscheme "tokyonight-moon").
    priority = 1000,
    lazy = theme.name ~= "tokyo_night_moon",
    opts = { style = "moon" },
  },
  {
    "ellisonleao/gruvbox.nvim",
    -- Same pattern as the others: always installed so the live-theme watcher can
    -- swap to it, eager only when active. Plugin-only (no hand-rolled colors/
    -- file); registers the "gruvbox" colorscheme and reads vim.o.background,
    -- which flexoki's init / the watcher set to "dark" for gruvbox_dark.
    priority = 1000,
    lazy = theme.name ~= "gruvbox_dark",
    opts = { contrast = "" }, -- "" = medium (#282828), matching Ghostty "Gruvbox Dark" + morhetz
  },
  {
    "blazkowolf/gruber-darker.nvim",
    -- Neovim-only colorscheme, deliberately NOT in config.theme's terminal map: it
    -- has no `$TERMINAL_THEME` counterpart, so it never starts eagerly and the
    -- live-swap watcher (config/autocmds.lua) never targets it. Installed but lazy;
    -- LazyVim's ColorSchemePre autoloads it on demand when you run
    -- `:colorscheme gruber-darker`. (The next `theme-set` swaps nvim back to the
    -- mapped terminal theme.) Defaults already italicize strings/comments/folds,
    -- which mirrors the Zed "Gruber Darker" look this is ported from.
    priority = 1000,
    lazy = true,
    -- Match the Zed config's `syntax.title` override: paint markdown section
    -- headers gruber yellow (#ffdd33) instead of upstream's quartz/blue. The
    -- per-level @markup.heading.N.markdown groups cover both raw treesitter
    -- headings and render-markdown.nvim (its RenderMarkdownH1..H6 link to them);
    -- the base @markup.heading is left alone so table headers don't go yellow.
    -- Registered in init() so it's armed before any `:colorscheme gruber-darker`.
    init = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "gruber-darker",
        callback = function()
          for level = 1, 6 do
            vim.api.nvim_set_hl(0, ("@markup.heading.%d.markdown"):format(level), { fg = "#ffdd33" })
          end
        end,
      })
    end,
  },
  {
    "rose-pine/neovim",
    enabled = false,
    priority = 1000,
    lazy = false,
    opts = {
      variant = "dawn",
      styles = { bold = true, italic = false, transparency = false },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- Always installed so the live-theme watcher can swap to it; loaded eagerly
    -- only when it's the active theme, lazily otherwise (lazy.nvim's
    -- ColorSchemePre autoloads it the first time :colorscheme runs).
    priority = 1000,
    lazy = theme.name ~= "catppuccin_mocha",
    opts = {
      flavour = "mocha",
      integrations = {
        blink_cmp = true,
        mason = true,
        noice = true,
        copilot_vim = true,
        which_key = true,
      },
    },
  },
  {
    "kepano/flexoki-neovim",
    name = "flexoki",
    -- Same pattern as catppuccin: always installed, eager only when active.
    priority = 1000,
    lazy = theme.name ~= "flexoki_light",
    init = function()
      vim.o.background = theme.background
    end,
    -- flexoki here only ever stands in for flexoki_light, so pin the light
    -- variant (theme.background is captured once at startup and would be wrong
    -- if the watcher swaps in flexoki from a dark startup theme).
    opts = {
      variant = "light",
    },
    config = function(_, opts)
      require("flexoki").setup(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = theme.colorscheme },
  },
}

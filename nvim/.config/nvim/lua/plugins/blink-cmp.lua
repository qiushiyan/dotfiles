-- disable buffer provider
-- start with ; to trigger snippets
-- alt + number to select nth item
-- copilot at the bottom

-- NOTE: Specify the trigger character(s) used for luasnip
local trigger_text = ";"
return {
  "saghen/blink.cmp",
  version = "*",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    cmdline = {
      enabled = true,
      -- use 'inherit' to inherit mappings from top level `keymap` config
      keymap = { preset = "inherit" },
      sources = { "buffer", "cmdline" },
    },
    keymap = {
      preset = "enter",
      ["<Tab>"] = { "select_and_accept", "fallback" },
      ["<S-Tab>"] = {
        function(cmp)
          cmp.show({ providers = { "lsp" } })
        end,
        "fallback",
      },
      ["<C-e>"] = { "hide", "fallback" },
    },
    enabled = function()
      local filetype = vim.bo[0].filetype
      if filetype == "TelescopePrompt" or filetype == "minifiles" or filetype == "snacks_picker_input" then
        return false
      end
      return true
    end,
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = "mono",
    },
    snippets = {
      preset = "luasnip",
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },
    sources = {
      providers = {
        lsp = {
          name = "lsp",
          module = "blink.cmp.sources.lsp",
          score_offset = 100, -- the higher the number, the higher the priority
        },
        -- copilot = {
        --   name = "copilot",
        --   module = "blink-cmp-copilot",
        --   kind = "Copilot",
        --   score_offset = 90, -- the higher the number, the higher the priority
        --   async = true,
        -- },
        buffer = {
          name = "Buffer",
          enabled = false,
          max_items = 3,
          module = "blink.cmp.sources.buffer",
          min_keyword_length = 4,
          score_offset = 15, -- the higher the number, the higher the priority
        },
        snippets = {
          name = "snippets",
          enabled = true,
          max_items = 15,
          min_keyword_length = 2,
          module = "blink.cmp.sources.snippets",
          score_offset = 85, -- the higher the number, the higher the priority
          -- Only show snippets if I type the trigger_text characters, so
          -- to expand the "bash" snippet, if the trigger_text is ";" I have to
          should_show_items = function()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
            -- NOTE: remember that `trigger_text` is modified at the top of the file
            return before_cursor:match(trigger_text .. "%w*$") ~= nil
          end,
          -- After accepting the completion, delete the trigger_text characters
          -- from the final inserted text
          transform_items = function(_, items)
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
            local trigger_pos = before_cursor:find(trigger_text .. "[^" .. trigger_text .. "]*$")
            if trigger_pos then
              for _, item in ipairs(items) do
                item.textEdit = {
                  newText = item.insertText or item.label,
                  range = {
                    start = { line = vim.fn.line(".") - 1, character = trigger_pos - 1 },
                    ["end"] = { line = vim.fn.line(".") - 1, character = col },
                  },
                }
              end
            end
            -- WORKAROUND: After transforming snippet items (removing trigger prefix),
            -- we must reload the snippets source. Without this reload, blink.cmp
            -- gets into an inconsistent state where:
            -- 1. The completion menu shows stale items
            -- 2. Subsequent snippet expansions may fail or produce incorrect text
            -- 3. The cursor position tracking becomes unreliable
            --
            -- This is likely due to blink.cmp caching the original items and not
            -- detecting that our transform_items modified them in place.
            --
            -- TODO: Investigate if this is fixed in newer blink.cmp versions
            vim.schedule(function()
              require("blink.cmp").reload("snippets")
            end)
            return items
          end,
        },
      },
    },
  },
  opts_extend = { "sources.default" },
}

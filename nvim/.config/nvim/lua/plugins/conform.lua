-- Markdown formatting is explicit only (`<leader>cf`, which passes force=true).
-- Most markdown I open is documentation written by an agent that I'm only
-- reading; auto-formatting it on save/quit turns every visit into an
-- uncommitted diff. `vim.b.autoformat` is the single lever for that: both
-- LazyVim's format-on-save and the FocusLost/BufLeave autocmd below go through
-- LazyVim.format.enabled(), and a buffer-local value wins over the global one.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "markdown.mdx", "mdx" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- Auto-format a buffer with unsaved edits when focus is lost or I leave it.
-- Unmodified buffers are skipped: formatting a file I only viewed turns the
-- visit into a diff, and the formatter run (~100ms) would land on every buffer
-- switch, picker open, and tmux pane switch. Async so leaving never waits on
-- the formatter; conform drops the result if the buffer changes meanwhile.
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  pattern = "*",
  callback = function(args)
    local buf = args.buf or vim.api.nvim_get_current_buf()
    -- autoformat can be disabled per buffer or globally (see :LazyFormatInfo)
    local function wanted()
      return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified and LazyVim.format.enabled(buf)
    end
    if wanted() and vim.fn.mode() == "n" then
      -- Add a small delay to the formatting so it doesn’t interfere with
      -- CopilotChat’s or grug-far buffer initialization, this helps me to not
      -- get errors when using the "BufLeave" event above, if not using
      -- "BufLeave" the delay is not needed
      vim.defer_fn(function()
        if wanted() then
          require("conform").format({ bufnr = buf, async = true })
        end
      end, 100)
    end
  end,
})

return {
  "stevearc/conform.nvim",
  optional = true,
}

-- Auto-format when focus is lost or I leave the buffer
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  pattern = "*",
  callback = function(args)
    local buf = args.buf or vim.api.nvim_get_current_buf()
    -- Only format if the current mode is normal mode
    -- Only format if autoformat is enabled for the current buffer (if
    -- autoformat disabled globally the buffers inherits it, see :LazyFormatInfo)
    if LazyVim.format.enabled(buf) and vim.fn.mode() == "n" then
      -- Add a small delay to the formatting so it doesn’t interfere with
      -- CopilotChat’s or grug-far buffer initialization, this helps me to not
      -- get errors when using the "BufLeave" event above, if not using
      -- "BufLeave" the delay is not needed
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(buf) then
          require("conform").format({ bufnr = buf })
        end
      end, 100)
    end
  end,
})

return {
  "stevearc/conform.nvim",
  optional = true,
}

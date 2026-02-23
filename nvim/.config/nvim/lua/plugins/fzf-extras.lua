-- fzf-lua customizations
return {
  "ibhagwan/fzf-lua",
  opts = {
    oldfiles = {
      -- In Telescope, when I used <leader>fr, it would load old buffers.
      -- fzf lua does the same, but by default buffers visited in the current
      -- session are not included. I use <leader>fr all the time to switch
      -- back to buffers I was just in.
      include_current_session = true,
    },
    previewers = {
      builtin = {
        -- fzf-lua struggled to preview large minified JS files due to Treesitter.
        -- Disable syntax highlighting for files larger than 100KB.
        syntax_limit_b = 1024 * 100,
      },
    },
    grep = {
      -- Enable glob filtering in live_grep.
      -- Example: > enable --*/plugins/*
      rg_glob = true,
      glob_flag = "--iglob",
      glob_separator = "%s%-%-",
    },
  },
}

local mf_ignore_dirs = {
  ["node_modules"] = true,
  ["venv"] = true,
  [".next"] = true,
  [".vercel"] = true,
  [".target"] = true,
  [".velite"] = true,
  ["__pycache__"] = true,
  [".idea"] = true,
  [".git"] = true,
  [".turbo"] = true,
  [".Rproj.user"] = true,
}

local mf_ignore_files = {
  [".Rhistory"] = true,
  [".RData"] = true,
  [".DS_Store"] = true,
}

local mf_filter = function(entry)
  if entry.fs_type == "directory" and mf_ignore_dirs[entry.name] then
    return false
  elseif entry.fs_type == "file" and mf_ignore_files[entry.name] then
    return false
  else
    return true
  end
end

local mf_no_filter = function(entry)
  return true
end

local show_hidden = true
local mf_toggle_filter = function()
  show_hidden = not show_hidden
  local new_filter = show_hidden and mf_no_filter or mf_filter
  require("mini.files").refresh({ content = { filter = new_filter } })
end

return {
  {
    "nvim-mini/mini.files",
    lazy = false,
    opts = {
      content = {
        filter = function(entry)
          if entry.fs_type == "directory" and mf_ignore_dirs[entry.name] then
            return false
          elseif entry.fs_type == "file" and mf_ignore_files[entry.name] then
            return false
          else
            return true
          end
        end,
      },
      windows = {
        preview = true,
        width_focus = 35,
        width_preview = 45,
      },
      options = {
        use_as_default_explorer = true,
        -- To get this dir run :echo stdpath('data')
        permanent_delete = false,
      },
      mappings = {
        close = "q",
        -- Use this if you want to open several files
        go_in = "l",
        -- This opens the file, but quits out of mini.files (default L)
        go_in_plus = "<CR>",
        -- I swapped the following 2 (default go_out: h)
        -- go_out_plus: when you go out, it shows you only 1 item to the right
        -- go_out: shows you all the items to the right
        go_out = "H",
        go_out_plus = "h",
        reset = ",",
        reveal_cwd = ".",
        show_help = "g?",
        -- Default =
        synchronize = "=",
        trim_left = "<",
        trim_right = ">",
      },
      config = function()
        vim.api.nvim_create_autocmd("User", {
          pattern = "MiniFilesBufferCreate",
          callback = function(args)
            local buf_id = args.data.buf_id
            vim.keymap.set("n", "g.", mf_toggle_filter, { buffer = buf_id })
          end,
        })
      end,
    },
    keys = {
      {
        "<esc>",
        function()
          require("mini.files").close()
        end,
      },
      {
        "<leader>e",
        function()
          if not require("mini.files").close() then
            require("mini.files").open(vim.uv.cwd(), true)
          end
        end,
        desc = "Open mini.files (cwd)",
      },
      {
        "<leader>E",
        function()
          local buf_name = vim.api.nvim_buf_get_name(0)
          local dir_name = vim.fn.fnamemodify(buf_name, ":p:h")
          if vim.fn.filereadable(buf_name) == 1 then
            -- Pass the full file path to highlight the file
            require("mini.files").open(buf_name, true)
          elseif vim.fn.isdirectory(dir_name) == 1 then
            -- If the directory exists but the file doesn't, open the directory
            require("mini.files").open(dir_name, true)
          else
            -- If neither exists, fallback to the current working directory
            require("mini.files").open(vim.uv.cwd(), true)
          end
        end,
        desc = "Open mini.files (Directory of Current File)",
      },
    },
  },
  -- LazyVim auto-imports the editor.neo-tree extra as the default explorer on
  -- installs with install_version < 8; mini.files above is our explorer, so
  -- keep neo-tree disabled or lazy will install and load it.
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}

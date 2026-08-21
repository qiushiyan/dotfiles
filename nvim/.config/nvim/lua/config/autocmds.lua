-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Match the host terminal's background to Neovim's so terminal window padding
-- (Ghostty: window-padding-x/y) blends with the editor instead of showing a
-- mismatched border. OSC 11 sets it on enter/colorscheme; OSC 111 resets it on exit.
--
-- Skipped on Apple Terminal: it honors the OSC 11 *set* but ignores the OSC 111
-- *reset* (and won't answer OSC 11 queries, so saving/restoring the real bg can't
-- work either), so a dark colorscheme would leave the terminal stuck dark after
-- quitting. It also has no inner padding, so the blend buys nothing there. Ghostty
-- / kitty / wezterm / iTerm2 reset correctly.
if vim.env.TERM_PROGRAM ~= "Apple_Terminal" then
  vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
    callback = function()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      if not normal.bg then
        return
      end
      io.write(string.format("\027]11;#%06x\027\\", normal.bg))
    end,
  })
  vim.api.nvim_create_autocmd("UILeave", {
    callback = function()
      io.write("\027]111\027\\")
    end,
  })
end

-- close neovim if all named buffers are closed
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    -- Check if this is the last buffer
    local bufs = vim.fn.getbufinfo({ buflisted = true })
    if #bufs == 1 then
      -- Check if it's an unnamed buffer with no changes
      local curr_buf = bufs[1]
      if curr_buf.name == "" and not curr_buf.changed then
        vim.cmd("quit")
      end
    end
  end,
})
-- automatically adds "-" or "*" once I type the first character and keeps track of indentation for markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.formatoptions:append("r") -- `<CR>` in insert mode
    vim.opt_local.formatoptions:append("o") -- `o` in normal mode
    vim.opt_local.comments = {
      "b:- [ ]", -- tasks
      "b:- [x]",
      "b:*", -- unordered list
      "b:-",
      "b:+",
    }
  end,
})

-- Live theme switching. `theme-set` (the shared switcher behind tmux `prefix t`)
-- writes the canonical name to ~/.config/terminal-theme; every running nvim
-- watches that file and re-applies the matching colorscheme without a restart.
-- fs_poll, not fs_event: on macOS fs_event watches the inode and goes stale on
-- the atomic rename theme-set does, so it would only ever fire once. lazy.nvim's
-- ColorSchemePre autoloads the matching (lazy) colorscheme plugin when
-- :colorscheme runs, so swapping in any direction works.
do
  local theme = require("config.theme")
  local state = vim.fn.expand("~/.config/terminal-theme")

  local function read_name()
    local f = io.open(state, "r")
    if not f then
      return nil
    end
    local line = (f:read("*l") or ""):gsub("%s+", "")
    f:close()
    return line ~= "" and line or nil
  end

  local function apply(name)
    local entry = theme.map[name]
    if not entry then
      return
    end
    if entry.colorscheme == vim.g.colors_name then
      return -- already on it
    end
    if entry.background then
      vim.o.background = entry.background
    end
    pcall(vim.cmd.colorscheme, entry.colorscheme)
  end

  if vim.uv and read_name() then -- only watch if the state file exists
    local poll = vim.uv.new_fs_poll()
    if poll then
      poll:start(
        state,
        1000,
        vim.schedule_wrap(function(err)
          if err then
            return
          end
          local name = read_name()
          if name then
            apply(name)
          end
        end)
      )
    end
  end
end

-- tmux `prefix y` / `prefix Y` are Neovim-aware through this block: it
-- publishes the focused file's absolute and cwd-relative paths into the
-- pane-scoped user options @yank_path / @yank_path_rel, and unsets them when
-- the focused buffer isn't a copyable file, so the tmux bindings fall back to
-- the pane cwd. Nvim pushes the resolved answer rather than tmux querying it
-- over RPC because "is this path worth copying" is a buffer-domain question —
-- buftype, .git/ edit files (COMMIT_EDITMSG, rebase-todo), Claude Code's
-- Ctrl+G claude-prompt-*.md are all real files an outside `[ -f ]` check
-- can't reject. Same push pattern as tmux-claude-ctx.sh's @ options.
-- The explicit -t matters: `tmux set -p` without it falls back to the
-- *client's* active pane when TMUX_PANE is unset (true inside display-popup),
-- silently writing some other pane's options.
do
  local pane = vim.env.TMUX_PANE
  if pane and vim.fn.executable("tmux") == 1 then
    local last -- last published "abs\nrel" ("" = unset); nil forces a publish

    local function copyable_path()
      if vim.bo.buftype ~= "" then
        return nil
      end
      local name = vim.api.nvim_buf_get_name(0)
      if name == "" or not vim.uv.fs_stat(name) then
        return nil
      end
      -- real files whose meaning is transient: git edit files, Ctrl+G prompts
      if name:find("/%.git/") or name:find("claude%-prompt%-") then
        return nil
      end
      return name
    end

    -- deferred one tick and coalesced: plugins (mini.icons among them) enter
    -- scratch buffers transiently mid-startup, and publishing synchronously
    -- from those BufEnters would unset the options right after the real
    -- buffer set them. By the scheduled read the dust has settled.
    local scheduled = false
    local function publish()
      if scheduled then
        return
      end
      scheduled = true
      vim.schedule(function()
        scheduled = false
        local abs = copyable_path()
        local rel = abs and vim.fn.fnamemodify(abs, ":.") or nil
        local key = abs and (abs .. "\n" .. rel) or ""
        if key == last then
          return
        end
        last = key
        local cmd
        if abs then
          -- one tmux invocation; ";" is tmux's command separator, no shell involved
          cmd = { "tmux", "set", "-p", "-t", pane, "@yank_path", abs, ";", "set", "-p", "-t", pane, "@yank_path_rel", rel }
        else
          cmd = { "tmux", "set", "-pu", "-t", pane, "@yank_path", ";", "set", "-pu", "-t", pane, "@yank_path_rel" }
        end
        vim.system(cmd, {})
      end)
    end

    local group = vim.api.nvim_create_augroup("TmuxYankPath", { clear = true })
    vim.api.nvim_create_autocmd(
      { "BufEnter", "WinEnter", "BufFilePost", "DirChanged", "FocusGained", "VimResume" },
      { group = group, callback = publish }
    )
    -- unset on exit/suspend so a shell in the same pane copies its cwd again;
    -- VimResume above re-publishes because `last` is reset here. Synchronous
    -- (short wait), because vim.schedule callbacks and detached children
    -- aren't guaranteed to survive nvim's exit.
    vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
      group = group,
      callback = function()
        vim.system({ "tmux", "set", "-pu", "-t", pane, "@yank_path", ";", "set", "-pu", "-t", pane, "@yank_path_rel" }, {}):wait(200)
        last = nil
      end,
    })
    -- this file loads on VeryLazy, after the initial BufEnter already fired —
    -- publish the startup buffer directly or it stays unpublished until the
    -- first buffer/focus change
    publish()
  end
end

-- custom macros
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
vim.api.nvim_create_augroup("JSLogMacro", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = "JSLogMacro",
  pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
  callback = function()
    vim.fn.setreg("l", "yoconsole.log('" .. esc .. "pa:" .. esc .. "la," .. esc .. "pl")
  end,
})

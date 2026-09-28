-- Sessions (persistence.nvim 3.x) are keyed by cwd (+ branch), so an nvim
-- launched as another program's editor -- Claude's Ctrl+G prompt, Codex's
-- editor, zsh's edit-command-line, a git commit -- would overwrite the
-- project's session with one that reopens a temp file deleted moments later.
-- Two guards:
-- 1. Launched only on such files: this nvim never saves a session.
-- 2. Before any save: wipe buffers outside the cwd, and ephemeral files inside
--    it, so the session holds only the project's own files. 3.x dropped the
--    `pre_save` option this used to be passed as; PersistenceSavePre replaces it.

local tmp_roots = { "/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/" }
if vim.env.TMPDIR and vim.env.TMPDIR ~= "" then
  tmp_roots[#tmp_roots + 1] = vim.fs.normalize(vim.env.TMPDIR) .. "/"
end

---@param path string
local function is_ephemeral(path)
  if path == "" then
    return false
  end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  if require("claude-prompt").is_prompt_file(path) then
    return true
  end
  -- COMMIT_EDITMSG, git-rebase-todo, TAG_EDITMSG, ...
  if path:find("/%.git/") then
    return true
  end
  -- Codex's $EDITOR files: ~/.codex*/.../editor/.tmpXXXXXX.md
  if path:find("/%.codex[^/]*/") and path:find("/editor/%.tmp[^/]*$") then
    return true
  end
  for _, root in ipairs(tmp_roots) do
    if vim.startswith(path, root) then
      return true
    end
  end
  return false
end

local function launched_as_editor()
  local args = vim.fn.argv() --[[@as string[] ]]
  if #args == 0 then
    return false
  end
  for _, arg in ipairs(args) do
    if not is_ephemeral(arg) then
      return false
    end
  end
  return true
end

local function prune_session()
  local cwd = vim.fn.getcwd() .. "/"
  local function drop(path)
    return not vim.startswith(vim.fn.fnamemodify(path, ":p") .. "/", cwd) or is_ephemeral(path)
  end
  -- the arglist is saved too, and restoring it recreates its buffers
  for i = vim.fn.argc() - 1, 0, -1 do
    if drop(vim.fn.argv(i)) then
      vim.cmd((i + 1) .. "argdelete")
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if drop(vim.api.nvim_buf_get_name(buf)) then
      -- modified buffers refuse deletion and stay in the session
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

return {
  {
    "folke/persistence.nvim",
    ---@module "persistence.nvim"
    ---@type Persistence.Config
    opts = {},
    config = function(_, opts)
      local persistence = require("persistence")
      persistence.setup(opts)
      if launched_as_editor() then
        persistence.stop()
        return
      end
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("PersistencePrune", { clear = true }),
        pattern = "PersistenceSavePre",
        callback = prune_session,
      })
    end,
  },
}

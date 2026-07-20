-- blink.cmp source completing project-local Claude Code skills as slash
-- commands (/skill-name) in Ctrl+G prompt buffers (claude-prompt-*.md).
--
-- The prompt file lives in the system temp dir, but Claude Code spawns the
-- editor with the project as its working directory, so the project is
-- recovered from getcwd(), never from the buffer path.

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  local name = vim.api.nvim_buf_get_name(0)
  return vim.fs.basename(name):match("^claude%-prompt%-") ~= nil
end

function source:get_trigger_characters()
  return { "/" }
end

-- Walk up from the editor's cwd to find <project>/.claude. Stops before
-- $HOME so ~/.claude is never mistaken for a project dir — the global skills
-- are merged in explicitly instead.
local function project_claude_dir()
  return vim.fs.find(".claude", {
    path = vim.fn.getcwd(),
    upward = true,
    type = "directory",
    stop = vim.uv.os_homedir(),
  })[1]
end

-- Gather <skills_dir>/<name>/SKILL.md entries into by_name. Called global
-- first, then project, so project skills override same-named global ones —
-- the same precedence Claude Code applies.
local function collect_skills(skills_dir, origin, by_name)
  if not vim.uv.fs_stat(skills_dir) then
    return
  end
  for name, entry_type in vim.fs.dir(skills_dir) do
    if entry_type == "directory" or entry_type == "link" then
      local skill_md = vim.fs.joinpath(skills_dir, name, "SKILL.md")
      if vim.uv.fs_stat(skill_md) then
        by_name[name] = { skill_md = skill_md, origin = origin }
      end
    end
  end
end

-- Extract `description:` from SKILL.md YAML frontmatter. Handles single-line
-- values and block scalars (>-, |) by joining the following indented lines.
local function skill_description(skill_md)
  local f = io.open(skill_md, "r")
  if not f then
    return nil
  end
  local lines = {}
  for line in f:lines() do
    lines[#lines + 1] = line
    if #lines >= 50 then
      break
    end
  end
  f:close()
  if lines[1] ~= "---" then
    return nil
  end
  for i = 2, #lines do
    local line = lines[i]
    if line == "---" then
      break
    end
    local value = line:match("^description:%s*(.*)$")
    if value then
      if value == "" or value:match("^[>|]") then
        local parts = {}
        for j = i + 1, #lines do
          local cont = lines[j]:match("^%s%s+(.*)$")
          if not cont then
            break
          end
          parts[#parts + 1] = cont
        end
        return table.concat(parts, " ")
      end
      return value
    end
  end
  return nil
end

function source:get_completions(ctx, callback)
  local response = { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }

  -- Complete "/partial" at line start or after whitespace, anywhere in the
  -- line. Mid-prompt "/name" is plain text to Claude (only a leading slash is
  -- parsed as a command), but it works as a skill reference the model reads,
  -- so completing it is a typing convenience the normal input doesn't offer.
  local line = ctx.line or vim.api.nvim_get_current_line()
  local col = ctx.cursor[2]
  local before = line:sub(1, col)
  local slash_pos = before:match("^()/[%w%-_]*$") or before:match("%s()/[%w%-_]*$")
  if not slash_pos then
    return callback(response)
  end

  local by_name = {}
  collect_skills(vim.fs.joinpath(vim.uv.os_homedir(), ".claude", "skills"), "global", by_name)
  local claude_dir = project_claude_dir()
  if claude_dir then
    collect_skills(vim.fs.joinpath(claude_dir, "skills"), "project", by_name)
  end

  -- Keyword, not Function/Method: blink auto-appends `()` to those kinds.
  -- Falls back to the raw LSP kind number when blink isn't loaded (tests).
  local ok, types = pcall(require, "blink.cmp.types")
  local kind = ok and types.CompletionItemKind.Keyword or 14
  local row = ctx.cursor[1] - 1

  for name, skill in pairs(by_name) do
    response.items[#response.items + 1] = {
      label = "/" .. name,
      labelDetails = { description = skill.origin },
      kind = kind,
      filterText = name,
      documentation = skill_description(skill.skill_md),
      textEdit = {
        newText = "/" .. name .. " ",
        range = {
          start = { line = row, character = slash_pos - 1 },
          ["end"] = { line = row, character = col },
        },
      },
    }
  end

  callback(response)
end

return source

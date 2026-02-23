local utils = {}

function utils.expand_path(path)
  if path:sub(1, 1) == "~" then
    return os.getenv("HOME") .. path:sub(2)
  end
  return path
end

function utils.center_in(outer, inner)
  return (outer - inner) / 2
end

return utils

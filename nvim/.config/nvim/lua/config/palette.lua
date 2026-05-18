local M = {}

-- Flexoki exports a flat palette via require("flexoki.palette").palette();
-- we remap its keys onto the catppuccin-shaped table that ui.lua expects.
local function flexoki_palette()
  local ok, fp = pcall(require, "flexoki.palette")
  if ok and fp.palette then
    local p = fp.palette()
    return {
      base     = p["bg"],
      mantle   = p["ui"],
      crust    = p["bg-2"],
      surface0 = p["ui-2"],
      surface1 = p["ui-3"],
      surface2 = p["tx-3"],
      text     = p["tx"],
      subtext0 = p["tx-2"],
      subtext1 = p["tx-2"],
      overlay0 = p["tx-3"],
      overlay1 = p["tx-3"],
      blue     = p["bl"],
      green    = p["gr"],
      red      = p["re"],
      yellow   = p["ye"],
      mauve    = p["pu"],
      teal     = p["cy"],
      pink     = p["ma"],
      sky      = p["bl-2"],
    }
  end
  -- hardcoded fallback (flexoki light)
  return {
    base     = "#FFFCF0",
    mantle   = "#E6E4D9",
    crust    = "#F2F0E5",
    surface0 = "#DAD8CE",
    surface1 = "#CECDC3",
    surface2 = "#B7B5AC",
    text     = "#100F0F",
    subtext0 = "#6F6E69",
    subtext1 = "#6F6E69",
    overlay0 = "#B7B5AC",
    overlay1 = "#B7B5AC",
    blue     = "#205EA6",
    green    = "#66800B",
    red      = "#AF3029",
    yellow   = "#AD8301",
    mauve    = "#5E409D",
    teal     = "#24837B",
    pink     = "#A02F6F",
    sky      = "#4385BE",
  }
end

function M.get_palette()
  local scheme = vim.g.colors_name or ""

  if scheme:match("^tailwind%-dark%-contrast") then
    return {
      base = "#101828",
      mantle = "#1e2939",
      crust = "#0f172b",
      surface0 = "#364153",
      surface1 = "#4a5565",
      surface2 = "#6a7282",
      text = "#f9fafb",
      subtext0 = "#d1d5dc",
      subtext1 = "#99a1af",
      overlay0 = "#6a7282",
      overlay1 = "#99a1af",
      blue = "#00a6f4",
      green = "#00d492",
      red = "#ff637e",
      yellow = "#ffb900",
      mauve = "#c27aff",
      teal = "#46ecd5",
      pink = "#fb64b6",
      sky = "#51a2ff",
    }
  elseif scheme:match("^tailwind%-dark") then
    return {
      base = "#1d293d",
      mantle = "#314158",
      crust = "#0f172b",
      surface0 = "#45556c",
      surface1 = "#62748e",
      surface2 = "#90a1b9",
      text = "#f8fafc",
      subtext0 = "#cad5e2",
      subtext1 = "#90a1b9",
      overlay0 = "#62748e",
      overlay1 = "#90a1b9",
      blue = "#00a6f4",
      green = "#00d492",
      red = "#ff637e",
      yellow = "#ffb900",
      mauve = "#c27aff",
      teal = "#96f7e4",
      pink = "#fb64b6",
      sky = "#51a2ff",
    }
  elseif scheme:match("^flexoki") then
    local p = flexoki_palette()
    -- flexoki-cyan-50: subtle mint-cream tint, the only off-paper accent in
    -- flexoki's base table. Different hue from neutral grays so UI bars read
    -- as intentional accents rather than washed-out cream.
    p.bar_bg = "#EBF2E7"
    return p
  else
    -- catppuccin or any other theme with catppuccin palettes
    local ok, palettes = pcall(require, "catppuccin.palettes")
    if ok then
      return palettes.get_palette()
    end
    -- hardcoded fallback (catppuccin latte)
    return {
      base = "#eff1f5",
      mantle = "#e6e9ef",
      crust = "#dce0e8",
      surface0 = "#ccd0da",
      surface1 = "#bcc0cc",
      surface2 = "#acb0be",
      text = "#4c4f69",
      subtext0 = "#6c6f85",
      subtext1 = "#5c5f77",
      overlay0 = "#9ca0b0",
      overlay1 = "#8c8fa1",
      blue = "#1e66f5",
      green = "#40a02b",
      red = "#d20f39",
      yellow = "#df8e1d",
      mauve = "#8839ef",
      teal = "#179299",
      pink = "#ea76cb",
      sky = "#04a5e5",
    }
  end
end

return M

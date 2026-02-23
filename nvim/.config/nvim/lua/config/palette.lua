local M = {}

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

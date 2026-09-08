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
  elseif scheme:match("^tailwind%-light") then
    return {
      base = "#ffffff",
      mantle = "#f1f5f9",
      crust = "#e2e8f0",
      surface0 = "#cad5e2",
      surface1 = "#90a1b9",
      surface2 = "#62748e",
      text = "#1d293d",
      subtext0 = "#45556c",
      subtext1 = "#62748e",
      overlay0 = "#90a1b9",
      overlay1 = "#62748e",
      blue = "#155dfc",
      green = "#009966",
      red = "#c70036",
      yellow = "#e17100",
      mauve = "#9810fa",
      teal = "#0092b8",
      pink = "#e60076",
      sky = "#0084d1",
    }
  elseif scheme:match("^vitesse%-light") then
    -- Vitesse Refined Light Soft (colors/vitesse-light-soft.lua) mapped onto
    -- the catppuccin-shaped table ui.lua consumes.
    return {
      base = "#f1f0e9",
      mantle = "#eceae1",
      crust = "#e7e5db",
      surface0 = "#dcdbd6",
      surface1 = "#b8b5a9",
      surface2 = "#999999",
      text = "#393a34",
      subtext0 = "#6b6c66",
      subtext1 = "#52534c",
      overlay0 = "#aaaaaa",
      overlay1 = "#999999",
      blue = "#296aa3",
      green = "#1e754f",
      red = "#ab5959",
      yellow = "#998418",
      mauve = "#a13865",
      teal = "#2e8f82",
      pink = "#a13865",
      sky = "#2993a3",
      -- Pale sage band for the lualine bar: green-tinted so it reads as an
      -- intentional accent on the cream bg.
      bar_bg = "#e4eae0",
    }
  elseif scheme:match("^orng") then
    -- orng Light (colors/orng-light.lua), ported from the Zed "orng" extension,
    -- mapped onto the catppuccin-shaped table ui.lua consumes.
    return {
      base = "#fff7f1",
      mantle = "#faefe7",
      crust = "#f3e6dc",
      surface0 = "#f0ddd0",
      surface1 = "#d9c6b9",
      surface2 = "#b8b8b8",
      text = "#1a1a1a",
      subtext0 = "#6b6b6b",
      subtext1 = "#4a4a4a",
      overlay0 = "#a0a0a0",
      overlay1 = "#8a8a8a",
      blue = "#0062d1",
      green = "#317b46",
      red = "#d1383d",
      yellow = "#b0851f",
      mauve = "#c94d24",
      teal = "#318795",
      pink = "#ec5b2b",
      sky = "#4ba3b0",
      -- Pale peach band for the lualine bar: accent-tinted so it reads as an
      -- intentional band on the peach paper (the orng analogue of vitesse's
      -- sage bar_bg above).
      bar_bg = "#fbe6da",
    }
  elseif scheme:match("^forest%-night") then
    -- Forest Night (colors/forest-night.lua), ported from the VS Code theme,
    -- mapped onto the catppuccin-shaped table ui.lua consumes. Surfaces are
    -- the Omarchy colors.toml background/foreground scale.
    return {
      base = "#1a2125", -- background
      mantle = "#14191c", -- dark_background
      crust = "#0d1113", -- darker_background
      surface0 = "#222a30", -- lighter_background
      surface1 = "#3a4a55", -- selection
      surface2 = "#4a5568", -- muted
      text = "#c9d1d9", -- foreground
      subtext0 = "#6b7280", -- dark_foreground
      subtext1 = "#a8b3bd", -- light_foreground
      overlay0 = "#4a5568",
      overlay1 = "#6b7280",
      blue = "#66D9EF",
      green = "#8FBC8F", -- sage accent
      red = "#c78a7a", -- the editor error/deleted rose, not the hot-pink ANSI red
      yellow = "#F39C12",
      mauve = "#9B59B6",
      teal = "#4ECDC4",
      pink = "#9B59B6",
      sky = "#4ECDC4",
      -- Elevated slate band for the lualine bar: lighter_background, one step
      -- up from the #1a2125 editor bg so the statusline/tabline reads as an
      -- intentional band (the Forest Night analogue of night_owl's bar_bg).
      bar_bg = "#222a30",
    }
  elseif scheme:match("^waffle%-cat") then
    return {
      base = "#292025", mantle = "#1f181c", crust = "#151013",
      surface0 = "#362d30", surface1 = "#6b5650", surface2 = "#a58c82",
      text = "#fff4d8", subtext0 = "#a58c82", subtext1 = "#fff4d8", overlay0 = "#6b5650", overlay1 = "#a58c82",
      blue = "#c87d2a", green = "#9fad68", red = "#cf7358", yellow = "#e4c56d",
      mauve = "#c98c97", teal = "#9eb8b2", pink = "#ddb0b8", sky = "#c2d5d0",
      bar_bg = "#362d30", -- upstream coffee surface, elevated above the syrup editor
    }
  elseif scheme:match("^gruber%-darker") then
    return {
      base = "#181818", mantle = "#0e0e0e", crust = "#000000",
      surface0 = "#202020", surface1 = "#303030", surface2 = "#545454",
      text = "#e4e4ef", subtext0 = "#808080", subtext1 = "#95a99f", overlay0 = "#545454", overlay1 = "#808080",
      blue = "#96a6c8", green = "#73c936", red = "#f43841", yellow = "#ffdd33",
      mauve = "#9e95c7", teal = "#4ec9b0", pink = "#9e95c7", sky = "#96a6c8",
      bar_bg = "#202020", -- Zed status/tab bar surface
    }
  elseif scheme:match("^vellum") then
    -- Vellum (colors/vellum.lua): white paper, neutral ink, ochre accent.
    -- Surfaces are Tailwind's neutral scale; hues its 700 steps.
    return {
      base = "#ffffff", mantle = "#fafafa", crust = "#f5f5f5",
      surface0 = "#e5e5e5", surface1 = "#d4d4d4", surface2 = "#a1a1a1",
      text = "#1f2022", subtext0 = "#525252", subtext1 = "#404040", overlay0 = "#a1a1a1", overlay1 = "#737373",
      blue = "#1447e6", green = "#008236", red = "#c10007", yellow = "#9a6a18",
      mauve = "#9a6a18", teal = "#007595", pink = "#cb953d", sky = "#0092b8",
      -- Pale amber band for the lualine bar (amber 20/80 white): the one warm
      -- note on the white page, so the statusline reads as an intentional band.
      bar_bg = "#f5ead8",
    }
  elseif scheme:match("^token%-meridian%-light") then
    -- Meridian light surfaces and semantic hues from ThorstenRhau/token.
    return {
      base = "#fbf9f4", mantle = "#ecebe7", crust = "#e7e3dc",
      surface0 = "#eae9e5", surface1 = "#dedbd3", surface2 = "#b5b2ab",
      text = "#28323a", subtext0 = "#524b42", subtext1 = "#46535f",
      overlay0 = "#a8a49c", overlay1 = "#43505c",
      blue = "#0048b3", green = "#005f2f", red = "#286fc0", yellow = "#843900",
      mauve = "#7a1f7a", teal = "#095b62", pink = "#7a1f7a", sky = "#236bb5",
      bar_bg = "#ecebe7", -- bg1 distinguishes the statusline from paper.
    }
  elseif scheme:match("^token%-ultra%-dark") then
    -- Ultra dark surfaces and semantic hues from ThorstenRhau/token.
    return {
      base = "#272724", mantle = "#1d1d1c", crust = "#181817",
      surface0 = "#30302c", surface1 = "#383835", surface2 = "#3c3b36",
      text = "#c5c1b8", subtext0 = "#a39d94", subtext1 = "#a7a299",
      overlay0 = "#636360", overlay1 = "#8d8983",
      blue = "#8aa5bb", green = "#9ab58e", red = "#dd8384", yellow = "#f7c988",
      mauve = "#b296cb", teal = "#78aba4", pink = "#bea5d4", sky = "#88c0c0",
      bar_bg = "#30302c", -- bg4 lifts the statusline above charcoal.
    }
  elseif scheme:match("^gruvbox") then
    -- gruvbox.nvim's dark-medium palette mapped onto the catppuccin-shaped
    -- table ui.lua consumes. Without this branch the "gruvbox" colorscheme name
    -- falls through to the catppuccin else-arm below, so the lualine bar
    -- inherits mocha's mantle (#181825 — a cold navy) and clashes with
    -- gruvbox's warm #282828 editor bg. Hex values are gruvbox.nvim's palette.
    return {
      base = "#282828", -- dark0 (editor bg)
      mantle = "#1d2021", -- dark0_hard
      crust = "#1d2021", -- dark0_hard (darkest gruvbox neutral)
      surface0 = "#3c3836", -- dark1
      surface1 = "#504945", -- dark2
      surface2 = "#665c54", -- dark3
      text = "#ebdbb2", -- light1 (fg)
      subtext0 = "#a89984", -- light4
      subtext1 = "#bdae93", -- light3
      overlay0 = "#7c6f64", -- dark4
      overlay1 = "#928374", -- gray
      blue = "#83a598", -- bright_blue
      green = "#b8bb26", -- bright_green
      red = "#fb4934", -- bright_red
      yellow = "#fabd2f", -- bright_yellow
      mauve = "#d3869b", -- bright_purple
      teal = "#8ec07c", -- bright_aqua
      pink = "#b16286", -- neutral_purple
      sky = "#458588", -- neutral_blue
      -- Elevated warm band for the lualine bar: dark1, one step up from the
      -- #282828 editor bg so the statusline/tabline reads as an intentional
      -- band.
      bar_bg = "#3c3836",
    }
  elseif scheme:match("^night%-owl") then
    -- night-owl.nvim's palette (lua/night-owl/palette.lua, plus the Night Owl
    -- terminal accents) mapped onto the catppuccin-shaped table ui.lua consumes.
    -- Without this branch "night-owl" falls through to the catppuccin else-arm
    -- and the lualine bar inherits mocha's #181825, a purple-navy that clashes
    -- with Night Owl's teal-navy #011627.
    return {
      base = "#011627", -- editor bg
      mantle = "#01111d", -- tab_inactive_bg
      crust = "#010d18", -- dark
      surface0 = "#0b2942", -- tab_active_bg
      surface1 = "#1d3b53", -- visual
      surface2 = "#395a75", -- blue7
      text = "#d6deeb", -- fg
      subtext0 = "#7e97ac", -- gray6
      subtext1 = "#b2ccd6", -- blue12
      overlay0 = "#4b6479", -- line_number_fg
      overlay1 = "#5f7e97", -- ui_border
      blue = "#82aaff",
      green = "#addb67", -- signature lime (ANSI yellow slot)
      red = "#ef5350",
      yellow = "#ffeb95", -- bright yellow
      mauve = "#c792ea",
      teal = "#7fdbca",
      pink = "#c792ea",
      sky = "#21c7a8",
      -- Elevated navy band for the lualine bar: the plugin's active-tab bg, one
      -- step up from the #011627 editor bg so the statusline/tabline reads as an
      -- intentional band (the Night Owl analogue of gruvbox's bar_bg above).
      bar_bg = "#0b2942",
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

-- Tailwind CSS (light), ported from the Zed "Tailwind CSS Light (Enhanced)"
-- theme. Mirrors colors/tailwind-dark-contrast.lua group-for-group so the two
-- variants stay in lockstep; only the palette and the (light) syntax
-- assignments differ. Selectable via TERMINAL_THEME=tailwind_light.
vim.cmd("hi clear")
vim.g.colors_name = "tailwind-light-contrast"
vim.o.termguicolors = true
vim.o.background = "light"

local c = {
  bg = "#ffffff",
  bg_float = "#f1f5f9",
  bg_popup = "#f1f5f9",
  bg_sidebar = "#f8fafc",
  bg_highlight = "#e2e8f0",
  bg_visual = "#bedbff",
  bg_search = "#fee685",
  bg_cursorline = "#f1f5f9",

  fg = "#1d293d",
  fg_dim = "#314158",
  fg_muted = "#45556c",
  fg_dark = "#62748e",
  fg_gutter = "#90a1b9",

  border = "#cad5e2",

  -- accent (Tailwind light — saturated enough to read on white)
  blue = "#155dfc", -- keywords / labels
  blue_deep = "#1447e6", -- preproc / variable.special
  cyan = "#0092b8",
  green = "#009966",
  indigo = "#432dd7", -- strings
  magenta = "#9810fa", -- functions
  orange = "#e17100", -- types / numbers / constants
  amber = "#fe9a00", -- bright accent (search)
  pink = "#e60076",
  teal = "#00786f", -- regex / special strings
  sky = "#0084d1", -- tags
  red = "#c70036",
  red_bright = "#ec003f",

  -- diagnostics
  error = "#c70036",
  warn = "#e17100",
  info = "#2b7fff",
  hint = "#45556c",

  -- diff (light tints)
  diff_add = "#a4f4cf",
  diff_delete = "#ffccd3",
  diff_change = "#bedbff",
  diff_text = "#a3c4ff",

  -- git
  git_add = "#009966",
  git_delete = "#ec003f",
  git_change = "#155dfc",

  -- text that sits on a saturated accent background
  on_accent = "#ffffff",
  on_warm = "#0f172b",
}

local hi = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.bg_float })
hi("NormalNC", { fg = c.fg, bg = c.bg })
hi("Cursor", { fg = c.bg, bg = c.fg })
hi("CursorLine", { bg = c.bg_cursorline })
hi("CursorColumn", { bg = c.bg_cursorline })
hi("ColorColumn", { bg = c.bg_highlight })
hi("LineNr", { fg = c.fg_gutter })
hi("CursorLineNr", { fg = c.fg_dim, bold = true })
hi("SignColumn", { fg = c.fg_gutter, bg = c.bg })
hi("FoldColumn", { fg = c.fg_dark, bg = c.bg })
hi("Folded", { fg = c.fg_muted, bg = c.bg_highlight })
hi("VertSplit", { fg = c.border })
hi("WinSeparator", { fg = c.border })
hi("Visual", { bg = c.bg_visual })
hi("VisualNOS", { bg = c.bg_visual })
hi("Search", { bg = c.bg_search })
hi("IncSearch", { fg = c.on_warm, bg = c.amber })
hi("CurSearch", { fg = c.on_warm, bg = c.amber })
hi("Substitute", { fg = c.on_accent, bg = c.red })
hi("MatchParen", { fg = c.orange, bold = true })
hi("NonText", { fg = c.border })
hi("SpecialKey", { fg = c.border })
hi("Whitespace", { fg = c.border })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.blue })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.orange, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.blue })
hi("Question", { fg = c.green })
hi("QuickFixLine", { bg = c.bg_highlight })
hi("WildMenu", { bg = c.bg_visual })

-- Pmenu (autocomplete; blink.cmp links to these by default)
hi("Pmenu", { fg = c.fg, bg = c.bg_float })
hi("PmenuSel", { bg = c.bg_visual })
hi("PmenuSbar", { bg = c.bg_float })
hi("PmenuThumb", { bg = c.fg_gutter })

-- Statusline
hi("StatusLine", { fg = c.fg_dim, bg = c.bg_float })
hi("StatusLineNC", { fg = c.fg_dark, bg = c.bg_sidebar })

-- Tabline
hi("TabLine", { fg = c.fg_muted, bg = c.bg_sidebar })
hi("TabLineSel", { fg = c.fg, bg = c.bg })
hi("TabLineFill", { bg = c.bg_sidebar })

-- Floating windows
hi("FloatBorder", { fg = c.border, bg = c.bg_float })
hi("FloatTitle", { fg = c.fg_dim, bg = c.bg_float })
hi("WinBar", { fg = c.fg_dim, bg = c.bg })
hi("WinBarNC", { fg = c.fg_dark, bg = c.bg })

-- Syntax
hi("Comment", { fg = c.fg_dark, italic = true })
hi("Constant", { fg = c.orange })
hi("String", { fg = c.indigo })
hi("Character", { fg = c.indigo })
hi("Number", { fg = c.orange })
hi("Boolean", { fg = c.orange })
hi("Float", { fg = c.orange })
hi("Identifier", { fg = c.fg_dim })
hi("Function", { fg = c.magenta })
hi("Statement", { fg = c.blue })
hi("Conditional", { fg = c.blue })
hi("Repeat", { fg = c.blue })
hi("Label", { fg = c.blue })
hi("Operator", { fg = c.fg_dark })
hi("Keyword", { fg = c.blue })
hi("Exception", { fg = c.blue })
hi("PreProc", { fg = c.blue_deep })
hi("Include", { fg = c.blue_deep })
hi("Define", { fg = c.blue_deep })
hi("Macro", { fg = c.blue_deep })
hi("PreCondit", { fg = c.blue_deep })
hi("Type", { fg = c.orange })
hi("StorageClass", { fg = c.blue })
hi("Structure", { fg = c.orange })
hi("Typedef", { fg = c.orange })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.fg_muted })
hi("Tag", { fg = c.sky })
hi("Delimiter", { fg = c.fg_dark })
hi("SpecialComment", { fg = c.fg_dark, italic = true })
hi("Debug", { fg = c.orange })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.orange, bold = true })

-- Diff
hi("DiffAdd", { bg = c.diff_add })
hi("DiffChange", { bg = c.diff_change })
hi("DiffDelete", { bg = c.diff_delete })
hi("DiffText", { bg = c.diff_text })
hi("diffAdded", { fg = c.git_add })
hi("diffRemoved", { fg = c.git_delete })
hi("diffChanged", { fg = c.git_change })

-- Diagnostics
hi("DiagnosticError", { fg = c.error })
hi("DiagnosticWarn", { fg = c.warn })
hi("DiagnosticInfo", { fg = c.info })
hi("DiagnosticHint", { fg = c.hint })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hi("DiagnosticUnderlineWarn", { undercurl = true, sp = c.warn })
hi("DiagnosticUnderlineInfo", { undercurl = true, sp = c.info })
hi("DiagnosticUnderlineHint", { undercurl = true, sp = c.hint })
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#ffe4e6" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#fef3c6" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#dbeafe" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#f1f5f9" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg_dim })
hi("@variable.builtin", { fg = c.blue_deep })
hi("@variable.parameter", { fg = c.fg_muted })
hi("@variable.member", { fg = c.fg_dim })

hi("@constant", { fg = c.orange })
hi("@constant.builtin", { fg = c.orange })
hi("@constant.macro", { fg = c.orange })

hi("@module", { fg = c.fg_dim })
hi("@label", { fg = c.blue })

hi("@string", { fg = c.indigo })
hi("@string.escape", { fg = c.fg_dark })
hi("@string.regex", { fg = c.teal })
hi("@string.special", { fg = c.teal })

hi("@character", { fg = c.indigo })
hi("@number", { fg = c.orange })
hi("@boolean", { fg = c.orange })
hi("@float", { fg = c.orange })

hi("@function", { fg = c.magenta })
hi("@function.builtin", { fg = c.magenta })
hi("@function.call", { fg = c.magenta })
hi("@function.macro", { fg = c.magenta })
hi("@function.method", { fg = c.magenta })
hi("@function.method.call", { fg = c.magenta })

hi("@constructor", { fg = c.orange })

hi("@operator", { fg = c.fg_dark })

hi("@keyword", { fg = c.blue })
hi("@keyword.coroutine", { fg = c.blue })
hi("@keyword.function", { fg = c.blue })
hi("@keyword.operator", { fg = c.blue })
hi("@keyword.import", { fg = c.blue })
hi("@keyword.return", { fg = c.blue })
hi("@keyword.conditional", { fg = c.blue })
hi("@keyword.repeat", { fg = c.blue })
hi("@keyword.exception", { fg = c.blue })

hi("@type", { fg = c.orange })
hi("@type.builtin", { fg = c.orange })
hi("@type.qualifier", { fg = c.blue })
hi("@type.definition", { fg = c.orange })

hi("@property", { fg = c.fg_dim })
hi("@attribute", { fg = c.fg_muted })

hi("@punctuation.bracket", { fg = c.fg_dark })
hi("@punctuation.delimiter", { fg = c.fg_dark })
hi("@punctuation.special", { fg = c.fg_dark })

hi("@comment", { fg = c.fg_dark, italic = true })

hi("@tag", { fg = c.sky })
hi("@tag.attribute", { fg = c.fg_muted })
hi("@tag.delimiter", { fg = c.fg_dark })

hi("@markup.heading", { fg = c.orange, bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.strong", { bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.indigo })
hi("@markup.link.url", { fg = c.sky, underline = true })
hi("@markup.raw", { fg = c.indigo })
hi("@markup.list", { fg = c.blue })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.orange })
hi("@lsp.type.interface", { fg = c.orange })
hi("@lsp.type.keyword", { fg = c.blue })
hi("@lsp.type.namespace", { fg = c.fg_dim })
hi("@lsp.type.parameter", { fg = c.fg_muted })
hi("@lsp.type.property", { fg = c.fg_dim })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.magenta })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.blue_deep })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.blue })
hi("TelescopeMatching", { fg = c.orange, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.blue })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.magenta })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.green })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.blue })
hi("LazyH1", { fg = c.on_accent, bg = c.blue, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.magenta })
hi("WhichKeyGroup", { fg = c.blue })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#e2e8f0", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#cad5e2", nocombine = true })
hi("IblIndent", { fg = "#e2e8f0", nocombine = true })
hi("IblScope", { fg = "#cad5e2", nocombine = true })

-- Mini
hi("MiniIndentscopeSymbol", { fg = c.border })

-- Noice
hi("NoiceCmdlinePopup", { fg = c.fg, bg = c.bg_float })
hi("NoiceCmdlinePopupBorder", { fg = c.border })

-- Notify
hi("NotifyERRORBorder", { fg = c.error })
hi("NotifyWARNBorder", { fg = c.warn })
hi("NotifyINFOBorder", { fg = c.info })
hi("NotifyDEBUGBorder", { fg = c.fg_dark })
hi("NotifyTRACEBorder", { fg = c.magenta })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.magenta })

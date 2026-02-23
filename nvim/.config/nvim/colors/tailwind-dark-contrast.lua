vim.cmd("hi clear")
vim.g.colors_name = "tailwind-dark-contrast"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#101828",
  bg_float = "#1e2939",
  bg_popup = "#1e2939",
  bg_sidebar = "#101828",
  bg_highlight = "#1e2939",
  bg_visual = "#0c2038",
  bg_search = "#5e2d8b",
  bg_cursorline = "#182135",

  fg = "#f9fafb",
  fg_dim = "#d1d5dc",
  fg_muted = "#99a1af",
  fg_dark = "#6a7282",
  fg_gutter = "#6a7282",

  border = "#1e2939",

  -- accent
  blue = "#00a6f4",
  cyan = "#00d3f3",
  green = "#00d492",
  magenta = "#c27aff",
  orange = "#ffb900",
  pink = "#fb64b6",
  purple = "#a3b3ff",
  red = "#ff637e",
  teal = "#46ecd5",
  yellow = "#ffd230",

  -- diagnostics
  error = "#ff637e",
  warn = "#ffb900",
  info = "#51a2ff",
  hint = "#99a1af",

  -- diff
  diff_add = "#0a3c30",
  diff_delete = "#3e1a28",
  diff_change = "#142e50",
  diff_text = "#1d4470",

  -- git
  git_add = "#00d492",
  git_delete = "#ff637e",
  git_change = "#51a2ff",
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
hi("IncSearch", { fg = c.bg, bg = c.orange })
hi("CurSearch", { fg = c.bg, bg = c.orange })
hi("Substitute", { fg = c.bg, bg = c.red })
hi("MatchParen", { fg = c.orange, bold = true })
hi("NonText", { fg = c.fg_dark })
hi("SpecialKey", { fg = c.fg_dark })
hi("Whitespace", { fg = c.fg_dark })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.blue })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.teal, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.teal })
hi("Question", { fg = c.teal })
hi("QuickFixLine", { bg = c.bg_highlight })
hi("WildMenu", { bg = c.bg_visual })

-- Pmenu (autocomplete)
hi("Pmenu", { fg = c.fg, bg = c.bg_float })
hi("PmenuSel", { bg = c.bg_visual })
hi("PmenuSbar", { bg = c.bg_float })
hi("PmenuThumb", { bg = c.fg_dark })

-- Statusline
hi("StatusLine", { fg = c.fg_dim, bg = c.bg_float })
hi("StatusLineNC", { fg = c.fg_dark, bg = c.bg_highlight })

-- Tabline
hi("TabLine", { fg = c.fg_muted, bg = c.bg })
hi("TabLineSel", { fg = c.fg, bg = c.bg_float })
hi("TabLineFill", { bg = c.bg })

-- Floating windows
hi("FloatBorder", { fg = c.border, bg = c.bg_float })
hi("FloatTitle", { fg = c.fg_dim, bg = c.bg_float })
hi("WinBar", { fg = c.fg_dim, bg = c.bg })
hi("WinBarNC", { fg = c.fg_dark, bg = c.bg })

-- Syntax
hi("Comment", { fg = c.fg_dark, italic = true })
hi("Constant", { fg = c.pink })
hi("String", { fg = c.cyan })
hi("Character", { fg = c.cyan })
hi("Number", { fg = c.pink })
hi("Boolean", { fg = c.pink })
hi("Float", { fg = c.pink })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.teal })
hi("Statement", { fg = c.purple })
hi("Conditional", { fg = c.purple })
hi("Repeat", { fg = c.purple })
hi("Label", { fg = c.purple })
hi("Operator", { fg = c.fg_dark })
hi("Keyword", { fg = c.purple })
hi("Exception", { fg = c.purple })
hi("PreProc", { fg = c.purple })
hi("Include", { fg = c.purple })
hi("Define", { fg = c.purple })
hi("Macro", { fg = c.purple })
hi("PreCondit", { fg = c.purple })
hi("Type", { fg = c.teal })
hi("StorageClass", { fg = c.purple })
hi("Structure", { fg = c.teal })
hi("Typedef", { fg = c.teal })
hi("Special", { fg = c.fg_dim })
hi("SpecialChar", { fg = c.fg_dim })
hi("Tag", { fg = c.pink })
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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#1a1a2c" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#1c1c29" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#141d30" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#181f2f" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.red })
hi("@variable.parameter", { fg = c.fg_dim })
hi("@variable.member", { fg = c.fg_dim })

hi("@constant", { fg = c.pink })
hi("@constant.builtin", { fg = c.pink })
hi("@constant.macro", { fg = c.pink })

hi("@module", { fg = c.fg })
hi("@label", { fg = c.purple })

hi("@string", { fg = c.cyan })
hi("@string.escape", { fg = c.fg_dim })
hi("@string.regex", { fg = "#f4a8ff" })
hi("@string.special", { fg = "#f4a8ff" })

hi("@character", { fg = c.cyan })
hi("@number", { fg = c.pink })
hi("@boolean", { fg = c.pink })
hi("@float", { fg = c.pink })

hi("@function", { fg = c.teal })
hi("@function.builtin", { fg = c.teal })
hi("@function.call", { fg = c.teal })
hi("@function.macro", { fg = c.teal })
hi("@function.method", { fg = c.teal })
hi("@function.method.call", { fg = c.teal })

hi("@constructor", { fg = c.teal })

hi("@operator", { fg = c.fg_dark })

hi("@keyword", { fg = c.purple })
hi("@keyword.coroutine", { fg = c.purple })
hi("@keyword.function", { fg = c.purple })
hi("@keyword.operator", { fg = c.purple })
hi("@keyword.import", { fg = c.purple })
hi("@keyword.return", { fg = c.purple })
hi("@keyword.conditional", { fg = c.purple })
hi("@keyword.repeat", { fg = c.purple })
hi("@keyword.exception", { fg = c.purple })

hi("@type", { fg = c.teal })
hi("@type.builtin", { fg = c.teal })
hi("@type.qualifier", { fg = c.purple })
hi("@type.definition", { fg = c.teal })

hi("@property", { fg = c.fg_dim })
hi("@attribute", { fg = c.fg_dim })

hi("@punctuation.bracket", { fg = c.fg_dark })
hi("@punctuation.delimiter", { fg = c.fg_dark })
hi("@punctuation.special", { fg = c.fg_dark })

hi("@comment", { fg = c.fg_dark, italic = true })

hi("@tag", { fg = c.pink })
hi("@tag.attribute", { fg = c.fg_dim })
hi("@tag.delimiter", { fg = c.fg_dark })

hi("@markup.heading", { fg = c.teal, bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.strong", { bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.cyan })
hi("@markup.link.url", { fg = c.blue, underline = true })
hi("@markup.raw", { fg = c.cyan })
hi("@markup.list", { fg = c.purple })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.teal })
hi("@lsp.type.interface", { fg = c.teal })
hi("@lsp.type.keyword", { fg = c.purple })
hi("@lsp.type.namespace", { fg = c.fg })
hi("@lsp.type.parameter", { fg = c.fg_dim })
hi("@lsp.type.property", { fg = c.fg_dim })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.teal })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.red })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.blue })
hi("TelescopeMatching", { fg = c.orange, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.bg, bg = c.blue })
hi("TelescopeResultsTitle", { fg = c.bg, bg = c.teal })
hi("TelescopePreviewTitle", { fg = c.bg, bg = c.green })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.bg, bg = c.blue })
hi("LazyH1", { fg = c.bg, bg = c.blue, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.teal })
hi("WhichKeyGroup", { fg = c.purple })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#1a2232", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#1e2939", nocombine = true })
hi("IblIndent", { fg = "#1a2232", nocombine = true })
hi("IblScope", { fg = "#1e2939", nocombine = true })

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

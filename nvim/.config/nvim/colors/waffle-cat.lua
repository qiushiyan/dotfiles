-- Waffle Cat — OldJobobo/omarchy-waffle-cat-theme at 8ffff576d47c.
-- Source: https://github.com/OldJobobo/omarchy-waffle-cat-theme
-- colors.toml supplies surfaces; vscode-theme.json supplies syntax roles:
-- rose keywords, honey functions, gold types/numbers, green strings, ceramic
-- properties/parameters and oat comments (5.03:1 on bg, unchanged upstream).
-- Editor groups follow forest-night.lua. Diff/diagnostic/search/indent tints
-- flatten upstream alpha onto bg; change tints use the same gold convention.
-- Cursor line uses lighter_bg so it remains visible in a terminal. Selection
-- uses the opaque terminal selection, with cream popup text for contrast.
vim.cmd("hi clear")
vim.g.colors_name = "waffle-cat"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#292025",
  bg_float = "#1f181c",
  bg_popup = "#1f181c",
  bg_sidebar = "#292025",
  bg_highlight = "#362d30",
  bg_visual = "#6b5650",
  bg_search = "#513e2f",
  bg_cursorline = "#362d30",
  bg_popup_selected = "#473226",
  fg = "#fff4d8",
  fg_dim = "#fff4d8",
  fg_muted = "#a58c82",
  fg_dark = "#a58c82",
  fg_gutter = "#a58c82",
  border = "#6b5650",
  cursor = "#fffaf0",
  accent = "#c87d2a",
  gold = "#c8964b",
  butter = "#e4c56d",
  keyword = "#ddb0b8",
  operator = "#df9850",
  cyan = "#9eb8b2",
  bright_cyan = "#c2d5d0",
  green = "#9fad68",
  comment = "#a58c82",
  predictive = "#a58c82",
  error = "#cf7358",
  warn = "#c8964b",
  info = "#c87d2a",
  hint = "#9eb8b2",
  diff_add = "#38322d",
  diff_delete = "#3e2a2b",
  diff_change = "#3d2f2a",
  diff_text = "#513e2f",
  git_add = "#9fad68",
  git_delete = "#cf7358",
  git_change = "#c8964b",
  on_accent = "#151013",
  on_warm = "#151013",
  diag_error = "#372729",
  diag_warn = "#362a28",
  diag_info = "#362825",
  diag_hint = "#332d31",
  indent = "#403437",
  indent_active = "#675654",
}

local hi = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor
hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.bg_float })
hi("NormalNC", { fg = c.fg, bg = c.bg })
hi("Cursor", { fg = c.bg, bg = c.cursor })
hi("CursorLine", { bg = c.bg_cursorline })
hi("CursorColumn", { bg = c.bg_cursorline })
hi("ColorColumn", { bg = c.bg_highlight })
hi("LineNr", { fg = c.fg_gutter })
hi("CursorLineNr", { fg = c.cursor, bold = true })
hi("SignColumn", { fg = c.fg_gutter, bg = c.bg })
hi("FoldColumn", { fg = c.fg_dark, bg = c.bg })
hi("Folded", { fg = c.fg_muted, bg = c.bg_highlight })
hi("VertSplit", { fg = c.border })
hi("WinSeparator", { fg = c.border })
hi("Visual", { bg = c.bg_visual })
hi("VisualNOS", { bg = c.bg_visual })
hi("Search", { bg = c.bg_search })
hi("IncSearch", { fg = c.on_warm, bg = c.accent })
hi("CurSearch", { fg = c.on_warm, bg = c.accent })
hi("Substitute", { fg = c.on_accent, bg = c.error })
hi("MatchParen", { bg = c.bg_visual, bold = true })
hi("NonText", { fg = c.fg_gutter })
hi("SpecialKey", { fg = c.fg_gutter })
hi("Whitespace", { fg = c.fg_gutter })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.accent })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.accent, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.green })
hi("Question", { fg = c.green })
hi("QuickFixLine", { bg = c.bg_highlight })
hi("WildMenu", { bg = c.bg_visual })

-- Pmenu (autocomplete; blink.cmp links to these by default)
hi("Pmenu", { fg = c.fg, bg = c.bg_float })
hi("PmenuSel", { fg = c.fg, bg = c.bg_popup_selected })
hi("PmenuSbar", { bg = c.bg_float })
hi("PmenuThumb", { bg = c.fg_gutter })

-- Statusline
hi("StatusLine", { fg = c.fg_dim, bg = c.bg_highlight })
hi("StatusLineNC", { fg = c.fg_dark, bg = c.bg_float })

-- Tabline
hi("TabLine", { fg = c.fg_muted, bg = c.bg_float })
hi("TabLineSel", { fg = c.fg, bg = c.bg })
hi("TabLineFill", { bg = c.bg_float })

-- Floating windows
hi("FloatBorder", { fg = c.border, bg = c.bg_float })
hi("FloatTitle", { fg = c.fg_dim, bg = c.bg_float })
hi("WinBar", { fg = c.fg_dim, bg = c.bg })
hi("WinBarNC", { fg = c.fg_dark, bg = c.bg })

-- Syntax
hi("Comment", { fg = c.comment, italic = true })
hi("Constant", { fg = c.butter })
hi("String", { fg = c.green })
hi("Character", { fg = c.green })
hi("Number", { fg = c.gold })
hi("Boolean", { fg = c.gold })
hi("Float", { fg = c.gold })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.accent })
hi("Statement", { fg = c.keyword })
hi("Conditional", { fg = c.keyword, bold = true })
hi("Repeat", { fg = c.keyword, bold = true })
hi("Label", { fg = c.accent })
hi("Operator", { fg = c.operator })
hi("Keyword", { fg = c.keyword })
hi("Exception", { fg = c.keyword, bold = true })
hi("PreProc", { fg = c.cyan })
hi("Include", { fg = c.accent, italic = true })
hi("Define", { fg = c.cyan })
hi("Macro", { fg = c.cyan, bold = true })
hi("PreCondit", { fg = c.cyan })
hi("Type", { fg = c.gold })
hi("StorageClass", { fg = c.gold })
hi("Structure", { fg = c.gold })
hi("Typedef", { fg = c.gold })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.keyword, bold = true })
hi("Tag", { fg = c.gold })
hi("Delimiter", { fg = c.fg_muted })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.keyword })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.accent, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.diag_error })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = c.diag_warn })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.diag_info })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.diag_hint })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.fg, italic = true })
hi("@variable.parameter", { fg = c.cyan, italic = true })
hi("@variable.member", { fg = c.cyan })

hi("@constant", { fg = c.butter })
hi("@constant.builtin", { fg = c.cyan })
hi("@constant.macro", { fg = c.cyan, bold = true })

hi("@module", { fg = c.accent })
hi("@label", { fg = c.accent })

hi("@string", { fg = c.green })
hi("@string.escape", { fg = c.keyword, bold = true })
hi("@string.regex", { fg = c.bright_cyan })
hi("@string.special", { fg = c.operator })

hi("@character", { fg = c.green })
hi("@number", { fg = c.gold })
hi("@boolean", { fg = c.gold })
hi("@float", { fg = c.gold })

hi("@function", { fg = c.accent })
hi("@function.builtin", { fg = c.cyan, bold = true })
hi("@function.call", { fg = c.accent })
hi("@function.macro", { fg = c.cyan, bold = true })
hi("@function.method", { fg = c.accent })
hi("@function.method.call", { fg = c.accent })

hi("@constructor", { fg = c.gold })

hi("@operator", { fg = c.operator })

hi("@keyword", { fg = c.keyword })
hi("@keyword.coroutine", { fg = c.keyword })
hi("@keyword.function", { fg = c.keyword })
hi("@keyword.operator", { fg = c.operator })
hi("@keyword.import", { fg = c.accent, italic = true })
hi("@keyword.return", { fg = c.keyword, bold = true })
hi("@keyword.conditional", { fg = c.keyword, bold = true })
hi("@keyword.repeat", { fg = c.keyword, bold = true })
hi("@keyword.exception", { fg = c.keyword, bold = true })

hi("@type", { fg = c.gold })
hi("@type.builtin", { fg = c.fg })
hi("@type.qualifier", { fg = c.gold })
hi("@type.definition", { fg = c.gold })

hi("@property", { fg = c.cyan })
hi("@attribute", { fg = c.cyan, italic = true })

hi("@punctuation.bracket", { fg = c.fg_muted })
hi("@punctuation.delimiter", { fg = c.fg_muted })
hi("@punctuation.special", { fg = c.operator })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.gold })
hi("@tag.attribute", { fg = c.fg })
hi("@tag.delimiter", { fg = c.fg_muted })

hi("@markup.heading", { fg = c.accent, bold = true })
hi("@markup.italic", { fg = c.fg, italic = true })
hi("@markup.strong", { fg = c.fg, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.accent, underline = true })
hi("@markup.link.url", { fg = c.accent, underline = true })
hi("@markup.raw", { fg = c.green })
hi("@markup.list", { fg = c.cyan })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.gold })
hi("@lsp.type.interface", { fg = c.gold })
hi("@lsp.type.keyword", { fg = c.keyword })
hi("@lsp.type.namespace", { fg = c.accent })
hi("@lsp.type.parameter", { fg = c.cyan, italic = true })
hi("@lsp.type.property", { fg = c.cyan })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.cyan, bold = true })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.fg, italic = true })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.accent })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.accent })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.accent })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.green })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.accent })
hi("LazyH1", { fg = c.on_accent, bg = c.accent, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.accent })
hi("WhichKeyGroup", { fg = c.gold })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides: upstream muted at 0x30 / 0x80 opacity, flattened onto bg.
hi("IndentBlanklineChar", { fg = c.indent, nocombine = true })
hi("IndentBlanklineContextChar", { fg = c.indent_active, nocombine = true })
hi("IblIndent", { fg = c.indent, nocombine = true })
hi("IblScope", { fg = c.indent_active, nocombine = true })

-- Mini
hi("MiniIndentscopeSymbol", { fg = c.fg_gutter })

-- Noice
hi("NoiceCmdlinePopup", { fg = c.fg, bg = c.bg_float })
hi("NoiceCmdlinePopupBorder", { fg = c.border })

-- Notify
hi("NotifyERRORBorder", { fg = c.error })
hi("NotifyWARNBorder", { fg = c.warn })
hi("NotifyINFOBorder", { fg = c.info })
hi("NotifyDEBUGBorder", { fg = c.fg_dark })
hi("NotifyTRACEBorder", { fg = c.accent })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.accent })

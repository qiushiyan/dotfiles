-- Gruber Darker — th0jensen/gruber-darker.zed 0.0.8 (installed Zed theme).
-- https://github.com/th0jensen/gruber-darker.zed
-- Matches Zed's warm editor foreground, blue functions, yellow keywords,
-- green strings, brown comments, quartz properties/constants, plus the local
-- yellow Markdown titles and italic syntax overrides in zed/settings.json.
-- Editor/plugin groups follow waffle-cat.lua. Selection flattens #737373b3;
-- diff tints blend source semantic colors at 20% (changed text at 35%).
-- Hints and inline code use source text.disabled #808080 for legibility;
-- Zed's text.literal #68685b is only 3.15:1 on the charcoal.
-- Cursor line uses highlighted_line #282828 so focus remains visible.
vim.cmd("hi clear")
vim.g.colors_name = "gruber-darker"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#181818",
  bg_float = "#202020",
  bg_highlight = "#282828",
  bg_visual = "#585858",
  bg_search = "#585858",
  bg_cursorline = "#282828",
  bg_popup_selected = "#303030",
  fg = "#d1c7c5",
  fg_dim = "#95a99f",
  fg_muted = "#d1c7c5",
  fg_dark = "#808080",
  fg_gutter = "#545454",
  border = "#303030",
  cursor = "#ffdd33",
  accent = "#ffdd33",
  gold = "#d1c7c5",
  butter = "#95a99f",
  keyword = "#ffdd33",
  operator = "#d1c7c5",
  cyan = "#95a99f",
  bright_cyan = "#7cc138",
  green = "#7cc138",
  comment = "#cc8c3c",
  error = "#f43841",
  warn = "#ffdd33",
  info = "#96a6c8",
  hint = "#808080",
  diff_add = "#2a3b1e",
  diff_delete = "#441e20",
  diff_change = "#3c2f1f",
  diff_text = "#574125",
  git_add = "#73c936",
  git_delete = "#f43841",
  git_change = "#cc8c3c",
  on_accent = "#181818",
  on_warm = "#181818",
  diag_error = "#1a1a1a",
  diag_warn = "#0e0e0e",
  diag_info = "#0e0e0e",
  diag_hint = "#0e0e0e",
  indent = "#303030",
  indent_active = "#545454",
  func = "#96a6c8",
  constant = "#95a99f",
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
hi("Constant", { fg = c.constant, bold = true })
hi("String", { fg = c.green, italic = true })
hi("Character", { fg = c.green, italic = true })
hi("Number", { fg = c.gold })
hi("Boolean", { fg = c.keyword, italic = true, bold = true })
hi("Float", { fg = c.gold })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.func, italic = true })
hi("Statement", { fg = c.keyword, italic = true, bold = true })
hi("Conditional", { fg = c.keyword, italic = true, bold = true })
hi("Repeat", { fg = c.keyword, italic = true, bold = true })
hi("Label", { fg = c.fg })
hi("Operator", { fg = c.operator })
hi("Keyword", { fg = c.keyword, italic = true, bold = true })
hi("Exception", { fg = c.keyword, italic = true, bold = true })
hi("PreProc", { fg = c.constant })
hi("Include", { fg = c.constant })
hi("Define", { fg = c.constant })
hi("Macro", { fg = c.constant, bold = true })
hi("PreCondit", { fg = c.constant })
hi("Type", { fg = c.gold })
hi("StorageClass", { fg = c.keyword, italic = true, bold = true })
hi("Structure", { fg = c.gold })
hi("Typedef", { fg = c.gold })
hi("Special", { fg = c.fg })
hi("SpecialChar", { fg = c.green, italic = true })
hi("Tag", { fg = c.fg })
hi("Delimiter", { fg = c.fg_muted, italic = true })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.keyword, italic = true, bold = true })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.keyword, bold = true })

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
hi("@variable.builtin", { fg = c.fg })
hi("@variable.parameter", { fg = c.fg })
hi("@variable.member", { fg = c.constant })

hi("@constant", { fg = c.constant, bold = true })
hi("@constant.builtin", { fg = c.constant, bold = true })
hi("@constant.macro", { fg = c.constant, bold = true })

hi("@module", { fg = c.fg })
hi("@label", { fg = c.fg })

hi("@string", { fg = c.green, italic = true })
hi("@string.escape", { fg = c.green, italic = true })
hi("@string.regex", { fg = c.green, italic = true })
hi("@string.special", { fg = c.green, italic = true })

hi("@character", { fg = c.green, italic = true })
hi("@number", { fg = c.gold })
hi("@boolean", { fg = c.keyword, italic = true, bold = true })
hi("@float", { fg = c.gold })

hi("@function", { fg = c.func, italic = true })
hi("@function.builtin", { fg = c.func, italic = true })
hi("@function.call", { fg = c.func, italic = true })
hi("@function.macro", { fg = c.constant, bold = true })
hi("@function.method", { fg = c.func, italic = true })
hi("@function.method.call", { fg = c.func, italic = true })

hi("@constructor", { fg = c.keyword, italic = true, bold = true })

hi("@operator", { fg = c.operator })

hi("@keyword", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.coroutine", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.function", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.operator", { fg = c.operator })
hi("@keyword.import", { fg = c.constant })
hi("@keyword.return", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.conditional", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.repeat", { fg = c.keyword, italic = true, bold = true })
hi("@keyword.exception", { fg = c.keyword, italic = true, bold = true })

hi("@type", { fg = c.gold })
hi("@type.builtin", { fg = c.fg })
hi("@type.qualifier", { fg = c.gold })
hi("@type.definition", { fg = c.gold })

hi("@property", { fg = c.cyan })
hi("@attribute", { fg = c.constant, italic = true })

hi("@punctuation.bracket", { fg = c.fg_muted, italic = true })
hi("@punctuation.delimiter", { fg = c.fg_muted, italic = true })
hi("@punctuation.special", { fg = c.operator, italic = true })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.fg })
hi("@tag.attribute", { fg = c.constant, bold = true })
hi("@tag.delimiter", { fg = c.fg })

hi("@markup.heading", { fg = c.constant, bold = true })
hi("@markup.italic", { fg = c.fg, italic = true })
hi("@markup.strong", { fg = c.fg, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.func, underline = true })
hi("@markup.link.url", { fg = c.func, underline = true })
hi("@markup.raw", { fg = c.fg_dark })
hi("@markup.list", { fg = c.fg })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.gold })
hi("@lsp.type.interface", { fg = c.gold })
hi("@lsp.type.keyword", { fg = c.keyword, italic = true, bold = true })
hi("@lsp.type.namespace", { fg = c.fg })
hi("@lsp.type.parameter", { fg = c.fg })
hi("@lsp.type.property", { fg = c.cyan })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.func, italic = true })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.fg })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.accent })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.accent })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.func })
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

-- Zed theme_overrides.Gruber Darker.syntax.title; each rendered heading level.
-- Keep the base heading quartz so render-markdown table headers stay neutral.
for level = 1, 6 do
  hi(("@markup.heading.%d.markdown"):format(level), { fg = c.keyword, bold = true })
end

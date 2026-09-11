-- Raindrop dark — Ray.so (Raycast).
-- Source: https://github.com/raycast/ray-so/blob/6738b5810b34a00ad58edac30686d43db22db90c/app/(navigation)/(code)/store/themes.ts#L1422-L1466
-- Token roles follow util/theme-css-variables.ts: cyan keywords/punctuation,
-- mint functions/parameters/types, ice strings, blue constants/properties,
-- violet numbers/booleans/deletions. No warm tokens: errors use deletion violet,
-- warnings use ice. Original comment (3.82:1) and property (4.03:1) retained.
-- globals.css gives black at 75% over the blue gradient: flattened midpoint
-- #152435, elevated endpoint #24323F, mantle endpoint #07152B. Selection and
-- diff backgrounds blend source tokens at 20% (DiffText 35%, cursor line 6%).
vim.cmd("hi clear")
vim.g.colors_name = "raindrop"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#152435",
  bg_float = "#07152B",
  bg_popup = "#07152B",
  bg_sidebar = "#152435",
  bg_highlight = "#24323F",
  bg_visual = "#1A485D",
  bg_search = "#2F375A",
  bg_cursorline = "#1D2F40",
  fg = "#E4F2FF",
  fg_dim = "#9DD8EB",
  fg_muted = "#2ED9FF",
  fg_dark = "#6C808B",
  fg_gutter = "#455764",
  border = "#334453",
  cursor = "#E4F2FF",
  keyword = "#2ED9FF",
  func = "#1AD6B5",
  string = "#9DD8EB",
  property = "#008BB7",
  type = "#1AD6B5",
  number = "#9984EE",
  constant = "#008BB7",
  comment = "#6C808B",
  predictive = "#6C808B",
  error = "#9984EE",
  warn = "#9DD8EB",
  info = "#2ED9FF",
  hint = "#1AD6B5",
  diff_add = "#1A485D",
  diff_delete = "#2F375A",
  diff_change = "#11394F",
  diff_text = "#1E637C",
  git_add = "#2ED9FF",
  git_delete = "#9984EE",
  git_change = "#9DD8EB",
  on_accent = "#07152B",
  on_warm = "#07152B",
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
hi("IncSearch", { fg = c.on_warm, bg = c.keyword })
hi("CurSearch", { fg = c.on_warm, bg = c.keyword })
hi("Substitute", { fg = c.on_accent, bg = c.type })
hi("MatchParen", { bg = c.bg_visual, bold = true })
hi("NonText", { fg = c.fg_gutter })
hi("SpecialKey", { fg = c.fg_gutter })
hi("Whitespace", { fg = c.fg_gutter })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.string })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.keyword, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.string })
hi("Question", { fg = c.number })
hi("QuickFixLine", { bg = c.bg_highlight })
hi("WildMenu", { bg = c.bg_visual })

-- Pmenu (autocomplete; blink.cmp links to these by default)
hi("Pmenu", { fg = c.fg, bg = c.bg_float })
hi("PmenuSel", { fg = c.fg, bg = c.bg_visual })
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
hi("Constant", { fg = c.constant })
hi("String", { fg = c.string })
hi("Character", { fg = c.string })
hi("Number", { fg = c.number })
hi("Boolean", { fg = c.number })
hi("Float", { fg = c.number })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.func })
hi("Statement", { fg = c.keyword })
hi("Conditional", { fg = c.keyword, bold = true })
hi("Repeat", { fg = c.keyword, bold = true })
hi("Label", { fg = c.type })
hi("Operator", { fg = c.keyword })
hi("Keyword", { fg = c.keyword })
hi("Exception", { fg = c.keyword, bold = true })
hi("PreProc", { fg = c.keyword })
hi("Include", { fg = c.keyword, italic = true })
hi("Define", { fg = c.keyword })
hi("Macro", { fg = c.keyword, bold = true })
hi("PreCondit", { fg = c.keyword })
hi("Type", { fg = c.type })
hi("StorageClass", { fg = c.keyword })
hi("Structure", { fg = c.type })
hi("Typedef", { fg = c.type })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.keyword, bold = true })
hi("Tag", { fg = c.string })
hi("Delimiter", { fg = c.fg_muted })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.keyword })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.string, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.diff_delete })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = c.bg_highlight })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.diff_add })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.bg_highlight })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.constant })
hi("@variable.parameter", { fg = c.func })
hi("@variable.member", { fg = c.property })

hi("@constant", { fg = c.constant })
hi("@constant.builtin", { fg = c.constant })
hi("@constant.macro", { fg = c.keyword, bold = true })

hi("@module", { fg = c.type })
hi("@label", { fg = c.type })

hi("@string", { fg = c.string })
hi("@string.escape", { fg = c.keyword, bold = true })
hi("@string.regex", { fg = c.string })
hi("@string.special", { fg = c.string })

hi("@character", { fg = c.string })
hi("@number", { fg = c.number })
hi("@boolean", { fg = c.number })
hi("@float", { fg = c.number })

hi("@function", { fg = c.func })
hi("@function.builtin", { fg = c.func, bold = true })
hi("@function.call", { fg = c.func })
hi("@function.macro", { fg = c.keyword, bold = true })
hi("@function.method", { fg = c.func })
hi("@function.method.call", { fg = c.func })

hi("@constructor", { fg = c.type })

hi("@operator", { fg = c.keyword })

hi("@keyword", { fg = c.keyword })
hi("@keyword.coroutine", { fg = c.keyword })
hi("@keyword.function", { fg = c.keyword })
hi("@keyword.operator", { fg = c.keyword })
hi("@keyword.import", { fg = c.keyword, italic = true })
hi("@keyword.return", { fg = c.keyword, bold = true })
hi("@keyword.conditional", { fg = c.keyword, bold = true })
hi("@keyword.repeat", { fg = c.keyword, bold = true })
hi("@keyword.exception", { fg = c.keyword, bold = true })

hi("@type", { fg = c.type })
hi("@type.builtin", { fg = c.type })
hi("@type.qualifier", { fg = c.keyword })
hi("@type.definition", { fg = c.type })

hi("@property", { fg = c.property })
hi("@attribute", { fg = c.func })

hi("@punctuation.bracket", { fg = c.keyword })
hi("@punctuation.delimiter", { fg = c.fg_muted })
hi("@punctuation.special", { fg = c.keyword })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.string })
hi("@tag.attribute", { fg = c.func })
hi("@tag.delimiter", { fg = c.keyword })

hi("@markup.heading", { fg = c.keyword, bold = true })
hi("@markup.italic", { fg = c.fg, italic = true })
hi("@markup.strong", { fg = c.fg, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.keyword, underline = true })
hi("@markup.link.url", { fg = c.keyword, underline = true })
hi("@markup.raw", { fg = c.string })
hi("@markup.list", { fg = c.string })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.type })
hi("@lsp.type.interface", { fg = c.type })
hi("@lsp.type.keyword", { fg = c.keyword })
hi("@lsp.type.namespace", { fg = c.type })
hi("@lsp.type.parameter", { fg = c.func })
hi("@lsp.type.property", { fg = c.property })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.func, bold = true })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.constant })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.string })
hi("TelescopeMatching", { fg = c.string, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.string })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.func })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.number })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.string })
hi("LazyH1", { fg = c.on_accent, bg = c.string, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.string })
hi("WhichKeyGroup", { fg = c.keyword })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides: comment slate at 35% / 55% over the base.
hi("IndentBlanklineChar", { fg = c.border, nocombine = true })
hi("IndentBlanklineContextChar", { fg = c.fg_gutter, nocombine = true })
hi("IblIndent", { fg = c.border, nocombine = true })
hi("IblScope", { fg = c.fg_gutter, nocombine = true })

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
hi("NotifyTRACEBorder", { fg = c.func })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.func })

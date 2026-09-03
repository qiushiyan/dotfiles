-- Forest Night — Ethereal (ForrestKnight), ported from the VS Code theme's
-- tokenColors + workbench colors (the same palette the Omarchy theme's
-- colors.toml ships). Mirrors colors/orng-light.lua group-for-group so the
-- hand-rolled schemes stay in lockstep; only the palette and assignments
-- differ. Forest Night quirks kept on purpose: keywords, tags, decorators and
-- headings are the one amber; functions are purple; strings teal; properties,
-- template strings and links the brighter sky blue; types, `this`, regexes and
-- errors the rosy red; constants, numbers and booleans the sage accent;
-- operators and brackets stay foreground-coloured, punctuation a step dimmer.
-- One deviation: comments take the theme's doc-comment #6b7280 rather than its
-- #4a5568 (≈2.3:1 on the slate, unreadable at terminal sizes). Selectable via
-- TERMINAL_THEME=forest_night.
vim.cmd("hi clear")
vim.g.colors_name = "forest-night"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#1a2125",
  bg_float = "#14191c",
  bg_popup = "#14191c",
  bg_sidebar = "#1a2125",
  bg_highlight = "#222a30",
  bg_visual = "#3a4a55",
  bg_search = "#413250", -- editor.findMatchBackground (#9B59B6 @ 30%) on the slate
  bg_cursorline = "#1f272c",

  fg = "#c9d1d9",
  fg_dim = "#a8b3bd",
  fg_muted = "#8fa1b3", -- punctuation
  fg_dark = "#6b7280",
  fg_gutter = "#4a5568",

  border = "#2a2e33",
  cursor = "#6b8fa3", -- editorCursor / active line number / bracket-match border

  -- accent
  amber = "#F39C12", -- keywords / tags / decorators / headings / lists
  orange = "#E67E22",
  purple = "#9B59B6", -- functions
  teal = "#4ECDC4", -- strings / attributes / info / inline code
  sky = "#66D9EF", -- properties / template strings / links
  rose = "#c78a7a", -- types / classes / this / regex / errors
  green = "#8FBC8F", -- constants / numbers / booleans / diff add
  gold = "#FFB74D",
  comment = "#6b7280",
  predictive = "#4a5568",

  -- diagnostics
  error = "#c78a7a",
  warn = "#F39C12",
  info = "#4ECDC4",
  hint = "#6b7280",

  -- diff (the VS Code 20% tints, flattened onto the slate)
  diff_add = "#31403a",
  diff_delete = "#3d3636",
  diff_change = "#453a21",
  diff_text = "#664c1e",

  -- git
  git_add = "#8FBC8F",
  git_delete = "#c78a7a",
  git_change = "#F39C12",

  -- text that sits on a saturated accent background
  on_accent = "#1a2125",
  on_warm = "#1a2125",
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
hi("IncSearch", { fg = c.on_warm, bg = c.amber })
hi("CurSearch", { fg = c.on_warm, bg = c.amber })
hi("Substitute", { fg = c.on_accent, bg = c.rose })
hi("MatchParen", { bg = c.bg_visual, bold = true })
hi("NonText", { fg = c.fg_gutter })
hi("SpecialKey", { fg = c.fg_gutter })
hi("Whitespace", { fg = c.fg_gutter })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.teal })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.amber, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.teal })
hi("Question", { fg = c.green })
hi("QuickFixLine", { bg = c.bg_highlight })
hi("WildMenu", { bg = c.bg_visual })

-- Pmenu (autocomplete; blink.cmp links to these by default)
hi("Pmenu", { fg = c.fg, bg = c.bg_float })
hi("PmenuSel", { bg = "#2d3540" }) -- editorSuggestWidget.selectedBackground
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
hi("Constant", { fg = c.green })
hi("String", { fg = c.teal })
hi("Character", { fg = c.teal })
hi("Number", { fg = c.green })
hi("Boolean", { fg = c.green })
hi("Float", { fg = c.green })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.purple })
hi("Statement", { fg = c.amber })
hi("Conditional", { fg = c.amber, bold = true })
hi("Repeat", { fg = c.amber, bold = true })
hi("Label", { fg = c.rose })
hi("Operator", { fg = c.fg })
hi("Keyword", { fg = c.amber })
hi("Exception", { fg = c.amber, bold = true })
hi("PreProc", { fg = c.amber })
hi("Include", { fg = c.amber, italic = true })
hi("Define", { fg = c.amber })
hi("Macro", { fg = c.amber, bold = true })
hi("PreCondit", { fg = c.amber })
hi("Type", { fg = c.rose })
hi("StorageClass", { fg = c.amber })
hi("Structure", { fg = c.rose })
hi("Typedef", { fg = c.rose })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.amber, bold = true })
hi("Tag", { fg = c.amber })
hi("Delimiter", { fg = c.fg_muted })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.amber })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.teal, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#3d3636" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#453a21" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#244345" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#222a30" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.rose })
hi("@variable.parameter", { fg = c.fg })
hi("@variable.member", { fg = c.sky })

hi("@constant", { fg = c.green })
hi("@constant.builtin", { fg = c.green })
hi("@constant.macro", { fg = c.amber, bold = true })

hi("@module", { fg = c.rose })
hi("@label", { fg = c.rose })

hi("@string", { fg = c.teal })
hi("@string.escape", { fg = c.amber, bold = true })
hi("@string.regex", { fg = c.rose })
hi("@string.special", { fg = c.rose })

hi("@character", { fg = c.teal })
hi("@number", { fg = c.green })
hi("@boolean", { fg = c.green })
hi("@float", { fg = c.green })

hi("@function", { fg = c.purple })
hi("@function.builtin", { fg = c.purple, bold = true })
hi("@function.call", { fg = c.purple })
hi("@function.macro", { fg = c.amber, bold = true })
hi("@function.method", { fg = c.purple })
hi("@function.method.call", { fg = c.purple })

hi("@constructor", { fg = c.rose })

hi("@operator", { fg = c.fg })

hi("@keyword", { fg = c.amber })
hi("@keyword.coroutine", { fg = c.amber })
hi("@keyword.function", { fg = c.amber })
hi("@keyword.operator", { fg = c.amber })
hi("@keyword.import", { fg = c.amber, italic = true })
hi("@keyword.return", { fg = c.amber, bold = true })
hi("@keyword.conditional", { fg = c.amber, bold = true })
hi("@keyword.repeat", { fg = c.amber, bold = true })
hi("@keyword.exception", { fg = c.amber, bold = true })

hi("@type", { fg = c.rose })
hi("@type.builtin", { fg = c.rose })
hi("@type.qualifier", { fg = c.amber })
hi("@type.definition", { fg = c.rose })

hi("@property", { fg = c.sky })
hi("@attribute", { fg = c.amber })

hi("@punctuation.bracket", { fg = c.fg })
hi("@punctuation.delimiter", { fg = c.fg_muted })
hi("@punctuation.special", { fg = c.amber })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.amber })
hi("@tag.attribute", { fg = c.teal })
hi("@tag.delimiter", { fg = c.amber })

hi("@markup.heading", { fg = c.amber, bold = true })
hi("@markup.italic", { fg = c.fg, italic = true })
hi("@markup.strong", { fg = c.fg, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.sky, underline = true })
hi("@markup.link.url", { fg = c.sky, underline = true })
hi("@markup.raw", { fg = c.teal })
hi("@markup.list", { fg = c.amber })
hi("@markup.quote", { fg = c.comment, italic = true })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.rose })
hi("@lsp.type.interface", { fg = c.rose })
hi("@lsp.type.keyword", { fg = c.amber })
hi("@lsp.type.namespace", { fg = c.rose })
hi("@lsp.type.parameter", { fg = c.fg })
hi("@lsp.type.property", { fg = c.sky })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.purple, bold = true })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.rose })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.teal })
hi("TelescopeMatching", { fg = c.teal, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.teal })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.purple })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.green })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.teal })
hi("LazyH1", { fg = c.on_accent, bg = c.teal, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.teal })
hi("WhichKeyGroup", { fg = c.amber })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides (VS Code: #2a2e33 idle; its teal active guide is too loud for
-- an always-on scope line, so scope takes the muted slate instead)
hi("IndentBlanklineChar", { fg = "#2a2e33", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#4a5568", nocombine = true })
hi("IblIndent", { fg = "#2a2e33", nocombine = true })
hi("IblScope", { fg = "#4a5568", nocombine = true })

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
hi("NotifyTRACEBorder", { fg = c.purple })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.purple })

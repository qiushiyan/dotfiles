-- Vitesse Refined Light Soft, ported from the Zed "Vitesse Refined Light Soft"
-- theme (UI + syntax tokens). Mirrors colors/tailwind-light-contrast.lua
-- group-for-group so the hand-rolled schemes stay in lockstep; only the palette
-- and assignments differ. Vitesse quirks kept on purpose: base keywords and
-- operators are red while control-flow keywords are green, strings are brick
-- (not red), and variables/parameters are brown. Selectable via
-- TERMINAL_THEME=vitesse_light_soft.
vim.cmd("hi clear")
vim.g.colors_name = "vitesse-light-soft"
vim.o.termguicolors = true
vim.o.background = "light"

local c = {
  bg = "#f1f0e9",
  bg_float = "#eceae1",
  bg_popup = "#eceae1",
  bg_sidebar = "#edece4",
  bg_highlight = "#e7e5db",
  bg_visual = "#dcdbd6",
  bg_search = "#d8d2a2",
  bg_cursorline = "#eae8df",

  fg = "#393a34",
  fg_dim = "#4a4b44",
  fg_muted = "#6b6c66",
  fg_dark = "#999999",
  fg_gutter = "#a9a9a0",

  border = "#dbd7ca",

  -- accent (Vitesse — muted, earthy, saturated enough to read on cream)
  green = "#1e754f", -- control-flow keywords / tags / booleans
  green_fn = "#59873a", -- functions / labels
  accent = "#1c6b48", -- titles / headings (Vitesse primary)
  red = "#ab5959", -- base keywords / operators
  brick = "#b56959", -- strings
  orange = "#a65e2b", -- builtin variables / macros / warn
  gold = "#998418", -- properties
  gold_bright = "#bda437", -- bright accent (search)
  brown = "#b07d48", -- variables / parameters / constants
  blue = "#296aa3",
  indigo = "#5a6aa6", -- string escapes
  cyan = "#2993a3",
  teal = "#2e8f82", -- builtin types
  teal_deep = "#2e808f", -- types / namespaces
  number = "#2f798a",
  magenta = "#a13865",
  regex = "#ab5e3f",
  comment = "#a0ada0",

  -- diagnostics
  error = "#ab5959",
  warn = "#a65e2b",
  info = "#296aa3",
  hint = "#6b6c66",

  -- diff (light tints)
  diff_add = "#d8e5d5",
  diff_delete = "#ecd8d5",
  diff_change = "#d7e2ec",
  diff_text = "#bcd4e8",

  -- git
  git_add = "#1e754f",
  git_delete = "#ab5959",
  git_change = "#296aa3",

  -- text that sits on a saturated accent background
  on_accent = "#f1f0e9",
  on_warm = "#393a34",
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
hi("IncSearch", { fg = c.on_warm, bg = c.gold_bright })
hi("CurSearch", { fg = c.on_warm, bg = c.gold_bright })
hi("Substitute", { fg = c.on_accent, bg = c.red })
hi("MatchParen", { fg = c.accent, bold = true })
hi("NonText", { fg = c.border })
hi("SpecialKey", { fg = c.border })
hi("Whitespace", { fg = c.border })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.blue })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.accent, bold = true })
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
hi("Comment", { fg = c.comment, italic = true })
hi("Constant", { fg = c.brown })
hi("String", { fg = c.brick })
hi("Character", { fg = c.brick })
hi("Number", { fg = c.number })
hi("Boolean", { fg = c.green })
hi("Float", { fg = c.number })
hi("Identifier", { fg = c.brown })
hi("Function", { fg = c.green_fn })
hi("Statement", { fg = c.red })
hi("Conditional", { fg = c.green })
hi("Repeat", { fg = c.green })
hi("Label", { fg = c.green_fn })
hi("Operator", { fg = c.red })
hi("Keyword", { fg = c.red })
hi("Exception", { fg = c.green })
hi("PreProc", { fg = c.green })
hi("Include", { fg = c.green })
hi("Define", { fg = c.green })
hi("Macro", { fg = c.orange })
hi("PreCondit", { fg = c.green })
hi("Type", { fg = c.teal_deep })
hi("StorageClass", { fg = c.green })
hi("Structure", { fg = c.teal_deep })
hi("Typedef", { fg = c.teal_deep })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.indigo })
hi("Tag", { fg = c.green })
hi("Delimiter", { fg = c.fg_dark })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.orange })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.cyan, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#ecdcdc" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#ece1d3" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#dce4ec" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#e7e5db" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.brown })
hi("@variable.builtin", { fg = c.orange })
hi("@variable.parameter", { fg = c.brown })
hi("@variable.member", { fg = c.brown })

hi("@constant", { fg = c.brown })
hi("@constant.builtin", { fg = c.red })
hi("@constant.macro", { fg = c.orange })

hi("@module", { fg = c.teal_deep })
hi("@label", { fg = c.green_fn })

hi("@string", { fg = c.brick })
hi("@string.escape", { fg = c.indigo })
hi("@string.regex", { fg = c.regex })
hi("@string.special", { fg = c.brick })

hi("@character", { fg = c.brick })
hi("@number", { fg = c.number })
hi("@boolean", { fg = c.green })
hi("@float", { fg = c.number })

hi("@function", { fg = c.green_fn })
hi("@function.builtin", { fg = c.green_fn })
hi("@function.call", { fg = c.green_fn })
hi("@function.macro", { fg = c.green_fn })
hi("@function.method", { fg = c.green_fn })
hi("@function.method.call", { fg = c.green_fn })

hi("@constructor", { fg = c.green })

hi("@operator", { fg = c.red })

hi("@keyword", { fg = c.red })
hi("@keyword.coroutine", { fg = c.green })
hi("@keyword.function", { fg = c.green })
hi("@keyword.operator", { fg = c.green })
hi("@keyword.import", { fg = c.green })
hi("@keyword.return", { fg = c.green })
hi("@keyword.conditional", { fg = c.green })
hi("@keyword.repeat", { fg = c.green })
hi("@keyword.exception", { fg = c.green })

hi("@type", { fg = c.teal_deep })
hi("@type.builtin", { fg = c.teal })
hi("@type.qualifier", { fg = c.green })
hi("@type.definition", { fg = c.teal })

hi("@property", { fg = c.gold })
hi("@attribute", { fg = c.brown })

hi("@punctuation.bracket", { fg = c.fg_dark })
hi("@punctuation.delimiter", { fg = c.fg_dark })
hi("@punctuation.special", { fg = c.fg_dark })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.green })
hi("@tag.attribute", { fg = c.green })
hi("@tag.delimiter", { fg = c.green })

hi("@markup.heading", { fg = c.accent, bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.strong", { bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.brick })
hi("@markup.link.url", { fg = c.blue, underline = true })
hi("@markup.raw", { fg = c.brick })
hi("@markup.list", { fg = c.fg_dark })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.teal_deep })
hi("@lsp.type.interface", { fg = c.teal })
hi("@lsp.type.keyword", { fg = c.red })
hi("@lsp.type.namespace", { fg = c.teal_deep })
hi("@lsp.type.parameter", { fg = c.brown })
hi("@lsp.type.property", { fg = c.gold })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.green_fn })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.orange })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.green })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.green })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.magenta })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.teal })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.green })
hi("LazyH1", { fg = c.on_accent, bg = c.green, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.green_fn })
hi("WhichKeyGroup", { fg = c.green })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#e7e5db", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#d5d3c8", nocombine = true })
hi("IblIndent", { fg = "#e7e5db", nocombine = true })
hi("IblScope", { fg = "#d5d3c8", nocombine = true })

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

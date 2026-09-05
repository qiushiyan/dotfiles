-- Vellum, a house light theme: white paper, neutral ink, one ochre accent.
-- Hybrid of a screenshot (white bg, ink #1f2022, amber #cb953d table headers)
-- and Tailwind's palette (neutral grays for every surface; 700-step hues for
-- the chromatic tokens, the same family colors/tailwind-light-contrast.lua
-- uses). Mirrors colors/orng-light.lua group-for-group so the hand-rolled
-- schemes stay in lockstep; only the palette and assignments differ. The
-- token map is deliberately quiet: keywords and titles take the ochre,
-- functions blue, strings green, types teal, literals violet, and variables,
-- properties, operators and punctuation stay ink so code reads like prose on
-- paper. The sampled amber is 2.7:1 on white, so it only ever sits on
-- surfaces or as a bright highlight, never as body text; the ochre #9a6a18
-- (4.7:1) is the text-safe accent. Selectable via TERMINAL_THEME=vellum.
vim.cmd("hi clear")
vim.g.colors_name = "vellum"
vim.o.termguicolors = true
vim.o.background = "light"

local c = {
  bg = "#ffffff",
  bg_float = "#f5f5f5", -- neutral-100
  bg_popup = "#f5f5f5",
  bg_sidebar = "#fafafa", -- neutral-50
  bg_highlight = "#e5e5e5", -- neutral-200
  bg_visual = "#f5ead8", -- amber 20/80 white
  bg_search = "#eddabb", -- amber 35/65 white
  bg_cursorline = "#f7f7f7",

  fg = "#1f2022",
  fg_dim = "#404040", -- neutral-700
  fg_muted = "#525252", -- neutral-600
  fg_dark = "#737373", -- neutral-500
  fg_gutter = "#d4d4d4", -- neutral-300

  border = "#e5e5e5",

  -- accent
  ochre = "#9a6a18", -- keywords / titles / bold / cursor (text-safe accent)
  amber = "#cb953d", -- the sampled header amber: badges, caret, matchparen
  amber_deep = "#bb4d00", -- Tailwind amber-700: warnings
  blue = "#1447e6", -- functions (blue-700)
  blue_bright = "#155dfc", -- links (blue-600)
  green = "#008236", -- strings (green-700)
  green_bright = "#00a63e", -- green-600
  teal = "#007595", -- types / tag attributes (cyan-800; cyan-700 is 3.6:1)
  violet = "#7008e7", -- numbers / booleans / constants (violet-700)
  red = "#c10007", -- errors / deleted (red-700)
  comment = "#737373", -- neutral-500 (4.7:1)
  predictive = "#a1a1a1", -- neutral-400

  -- diagnostics
  error = "#c10007",
  warn = "#bb4d00",
  info = "#1447e6",
  hint = "#737373",

  -- diff (Tailwind 100/200 tints on white)
  diff_add = "#dcfce7",
  diff_delete = "#ffe2e2",
  diff_change = "#dbeafe",
  diff_text = "#bedbff",

  -- git
  git_add = "#008236",
  git_delete = "#c10007",
  git_change = "#9a6a18",

  -- text that sits on a saturated accent background
  on_accent = "#ffffff",
  on_warm = "#1f2022",
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
hi("MatchParen", { fg = c.ochre, bold = true })
hi("NonText", { fg = c.border })
hi("SpecialKey", { fg = c.border })
hi("Whitespace", { fg = c.border })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.blue })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.ochre, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.blue })
hi("Question", { fg = c.ochre })
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
hi("Constant", { fg = c.violet })
hi("String", { fg = c.green })
hi("Character", { fg = c.green })
hi("Number", { fg = c.violet })
hi("Boolean", { fg = c.violet })
hi("Float", { fg = c.violet })
hi("Identifier", { fg = c.fg })
hi("Function", { fg = c.blue })
hi("Statement", { fg = c.ochre })
hi("Conditional", { fg = c.ochre })
hi("Repeat", { fg = c.ochre })
hi("Label", { fg = c.ochre })
hi("Operator", { fg = c.fg_muted })
hi("Keyword", { fg = c.ochre })
hi("Exception", { fg = c.ochre })
hi("PreProc", { fg = c.ochre })
hi("Include", { fg = c.ochre })
hi("Define", { fg = c.ochre })
hi("Macro", { fg = c.blue })
hi("PreCondit", { fg = c.ochre })
hi("Type", { fg = c.teal })
hi("StorageClass", { fg = c.ochre })
hi("Structure", { fg = c.teal })
hi("Typedef", { fg = c.teal })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.violet })
hi("Tag", { fg = c.ochre })
hi("Delimiter", { fg = c.fg })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.red })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.blue, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#ffe2e2" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#ffedd4" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#dbeafe" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#f5f5f5" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.fg })
hi("@variable.builtin", { fg = c.ochre })
hi("@variable.parameter", { fg = c.fg_dim })
hi("@variable.member", { fg = c.fg_dim })

hi("@constant", { fg = c.violet })
hi("@constant.builtin", { fg = c.violet })
hi("@constant.macro", { fg = c.violet })

hi("@module", { fg = c.fg })
hi("@label", { fg = c.ochre })

hi("@string", { fg = c.green })
hi("@string.escape", { fg = c.violet })
hi("@string.regex", { fg = c.teal })
hi("@string.special", { fg = c.teal })

hi("@character", { fg = c.green })
hi("@number", { fg = c.violet })
hi("@boolean", { fg = c.violet })
hi("@float", { fg = c.violet })

hi("@function", { fg = c.blue })
hi("@function.builtin", { fg = c.blue })
hi("@function.call", { fg = c.blue })
hi("@function.macro", { fg = c.blue })
hi("@function.method", { fg = c.blue })
hi("@function.method.call", { fg = c.blue })

hi("@constructor", { fg = c.teal })

hi("@operator", { fg = c.fg_muted })

hi("@keyword", { fg = c.ochre })
hi("@keyword.coroutine", { fg = c.ochre })
hi("@keyword.function", { fg = c.ochre })
hi("@keyword.operator", { fg = c.ochre })
hi("@keyword.import", { fg = c.ochre })
hi("@keyword.return", { fg = c.ochre })
hi("@keyword.conditional", { fg = c.ochre })
hi("@keyword.repeat", { fg = c.ochre })
hi("@keyword.exception", { fg = c.ochre })

hi("@type", { fg = c.teal })
hi("@type.builtin", { fg = c.teal })
hi("@type.qualifier", { fg = c.ochre })
hi("@type.definition", { fg = c.teal })

hi("@property", { fg = c.fg_dim })
hi("@attribute", { fg = c.teal })

hi("@punctuation.bracket", { fg = c.fg })
hi("@punctuation.delimiter", { fg = c.fg })
hi("@punctuation.special", { fg = c.ochre })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.ochre })
hi("@tag.attribute", { fg = c.teal })
hi("@tag.delimiter", { fg = c.fg })

hi("@markup.heading", { fg = c.ochre, bold = true })
hi("@markup.italic", { fg = c.fg_dim, italic = true })
hi("@markup.strong", { fg = c.ochre, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.blue })
hi("@markup.link.url", { fg = c.blue_bright, underline = true })
hi("@markup.raw", { fg = c.green })
hi("@markup.list", { fg = c.ochre })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.teal })
hi("@lsp.type.interface", { fg = c.teal })
hi("@lsp.type.keyword", { fg = c.ochre })
hi("@lsp.type.namespace", { fg = c.fg })
hi("@lsp.type.parameter", { fg = c.fg_dim })
hi("@lsp.type.property", { fg = c.fg_dim })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.blue })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.ochre })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.amber })
hi("TelescopeMatching", { fg = c.ochre, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.ochre })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.blue })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.teal })

-- Snacks: names and status text need more contrast than NonText's border gray.
hi("SnacksPickerPathHidden", { fg = c.fg_dim })
hi("SnacksPickerPathIgnored", { fg = c.fg_muted })
hi("SnacksPickerGitStatusIgnored", { fg = c.fg_muted })
hi("SnacksPickerGitStatusUntracked", { fg = c.git_add })
hi("SnacksPickerTotals", { fg = c.fg_muted })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.ochre })
hi("LazyH1", { fg = c.on_accent, bg = c.ochre, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.blue })
hi("WhichKeyGroup", { fg = c.ochre })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#ededed", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#d4d4d4", nocombine = true })
hi("IblIndent", { fg = "#ededed", nocombine = true })
hi("IblScope", { fg = "#d4d4d4", nocombine = true })

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
hi("NotifyTRACEBorder", { fg = c.ochre })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.ochre })

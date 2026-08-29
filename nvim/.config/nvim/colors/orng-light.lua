-- orng Light, ported from the Zed "orng" extension's light variant (UI +
-- syntax tokens). Mirrors colors/vitesse-light-soft.lua group-for-group so the
-- hand-rolled schemes stay in lockstep; only the palette and assignments
-- differ. orng quirks kept on purpose: keywords, constants, numbers, booleans
-- and tags all share the one orange accent, functions/attributes are the
-- deeper brick orange, strings are a saturated blue, variables are red and
-- properties a soft blue. Terminal-side bg is the Zed *terminal* peach
-- (#fff7f1), not the white the Zed editor override uses — the terminal is the
-- warm frame. Selectable via TERMINAL_THEME=orng_light.
vim.cmd("hi clear")
vim.g.colors_name = "orng-light"
vim.o.termguicolors = true
vim.o.background = "light"

local c = {
  bg = "#fff7f1",
  bg_float = "#faefe7",
  bg_popup = "#faefe7",
  bg_sidebar = "#fcf2eb",
  bg_highlight = "#f3e6dc",
  bg_visual = "#f8dccd",
  bg_search = "#f8c0ac",
  bg_cursorline = "#fbede4",

  fg = "#1a1a1a",
  fg_dim = "#2e2e2e",
  fg_muted = "#6b6b6b",
  fg_dark = "#8a8a8a",
  fg_gutter = "#c4b5ac",

  border = "#eadbd1",

  -- accent (orng — one loud orange, everything else deferring to it)
  accent = "#ec5b2b", -- keywords / constants / numbers / tags / titles
  brick = "#c94d24", -- functions / attributes / constructors / bold
  red = "#d1383d", -- variables / enums
  blue = "#0062d1", -- strings
  blue_deep = "#0055b8", -- regex / special strings
  blue_soft = "#679cd9", -- properties
  teal = "#318795", -- operators / links / info
  teal_bright = "#4ba3b0",
  gold = "#b0851f", -- types / emphasis
  green = "#317b46", -- success / diff add (dim green; #3d9a57 is pale on peach)
  green_bright = "#3d9a57",
  comment = "#8a8a8a",
  predictive = "#a0a0a0",

  -- diagnostics
  error = "#d1383d",
  warn = "#ec5b2b",
  info = "#318795",
  hint = "#8a8a8a",

  -- diff (light tints on peach)
  diff_add = "#dcebdc",
  diff_delete = "#f6d7d4",
  diff_change = "#dbe6f3",
  diff_text = "#bfd5ee",

  -- git
  git_add = "#317b46",
  git_delete = "#d1383d",
  git_change = "#b0851f",

  -- text that sits on a saturated accent background
  on_accent = "#fff7f1",
  on_warm = "#1a1a1a",
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
hi("IncSearch", { fg = c.on_warm, bg = c.accent })
hi("CurSearch", { fg = c.on_warm, bg = c.accent })
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
hi("Question", { fg = c.accent })
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
hi("Constant", { fg = c.accent })
hi("String", { fg = c.blue })
hi("Character", { fg = c.blue })
hi("Number", { fg = c.accent })
hi("Boolean", { fg = c.accent })
hi("Float", { fg = c.accent })
hi("Identifier", { fg = c.red })
hi("Function", { fg = c.brick })
hi("Statement", { fg = c.accent })
hi("Conditional", { fg = c.accent })
hi("Repeat", { fg = c.accent })
hi("Label", { fg = c.brick })
hi("Operator", { fg = c.teal })
hi("Keyword", { fg = c.accent })
hi("Exception", { fg = c.accent })
hi("PreProc", { fg = c.accent })
hi("Include", { fg = c.accent })
hi("Define", { fg = c.accent })
hi("Macro", { fg = c.brick })
hi("PreCondit", { fg = c.accent })
hi("Type", { fg = c.gold })
hi("StorageClass", { fg = c.accent })
hi("Structure", { fg = c.gold })
hi("Typedef", { fg = c.gold })
hi("Special", { fg = c.fg_muted })
hi("SpecialChar", { fg = c.comment })
hi("Tag", { fg = c.accent })
hi("Delimiter", { fg = c.fg })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.brick })
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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#f6d7d4" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#f8dccd" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#dbe6f3" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#f3e6dc" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.red })
hi("@variable.builtin", { fg = c.brick })
hi("@variable.parameter", { fg = c.red })
hi("@variable.member", { fg = c.blue_soft })

hi("@constant", { fg = c.accent })
hi("@constant.builtin", { fg = c.accent })
hi("@constant.macro", { fg = c.brick })

hi("@module", { fg = c.fg })
hi("@label", { fg = c.brick })

hi("@string", { fg = c.blue })
hi("@string.escape", { fg = c.comment })
hi("@string.regex", { fg = c.blue_deep })
hi("@string.special", { fg = c.blue_deep })

hi("@character", { fg = c.blue })
hi("@number", { fg = c.accent })
hi("@boolean", { fg = c.accent })
hi("@float", { fg = c.accent })

hi("@function", { fg = c.brick })
hi("@function.builtin", { fg = c.brick })
hi("@function.call", { fg = c.brick })
hi("@function.macro", { fg = c.brick })
hi("@function.method", { fg = c.brick })
hi("@function.method.call", { fg = c.brick })

hi("@constructor", { fg = c.brick })

hi("@operator", { fg = c.teal })

hi("@keyword", { fg = c.accent })
hi("@keyword.coroutine", { fg = c.accent })
hi("@keyword.function", { fg = c.accent })
hi("@keyword.operator", { fg = c.accent })
hi("@keyword.import", { fg = c.accent })
hi("@keyword.return", { fg = c.accent })
hi("@keyword.conditional", { fg = c.accent })
hi("@keyword.repeat", { fg = c.accent })
hi("@keyword.exception", { fg = c.accent })

hi("@type", { fg = c.gold })
hi("@type.builtin", { fg = c.gold })
hi("@type.qualifier", { fg = c.accent })
hi("@type.definition", { fg = c.gold })

hi("@property", { fg = c.blue_soft })
hi("@attribute", { fg = c.brick })

hi("@punctuation.bracket", { fg = c.fg })
hi("@punctuation.delimiter", { fg = c.fg })
hi("@punctuation.special", { fg = c.accent })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.accent })
hi("@tag.attribute", { fg = c.brick })
hi("@tag.delimiter", { fg = c.fg })

hi("@markup.heading", { fg = c.accent, bold = true })
hi("@markup.italic", { fg = c.gold, italic = true })
hi("@markup.strong", { fg = c.accent, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.teal })
hi("@markup.link.url", { fg = c.blue, underline = true })
hi("@markup.raw", { fg = c.blue })
hi("@markup.list", { fg = c.accent })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.red })
hi("@lsp.type.interface", { fg = c.gold })
hi("@lsp.type.keyword", { fg = c.accent })
hi("@lsp.type.namespace", { fg = c.fg })
hi("@lsp.type.parameter", { fg = c.red })
hi("@lsp.type.property", { fg = c.blue_soft })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.brick })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.brick })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.accent })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.accent })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.brick })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.teal })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.accent })
hi("LazyH1", { fg = c.on_accent, bg = c.accent, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.brick })
hi("WhichKeyGroup", { fg = c.accent })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#f3e6dc", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#e0ccbf", nocombine = true })
hi("IblIndent", { fg = "#f3e6dc", nocombine = true })
hi("IblScope", { fg = "#e0ccbf", nocombine = true })

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
hi("NotifyTRACEBorder", { fg = c.brick })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.brick })

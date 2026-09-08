-- Token Ultra Dark — https://github.com/ThorstenRhau/token, revision 11be57ef6913
-- Palette: lua/token/palettes/ultra.lua; syntax: appearances/ultra_roles.lua.
-- Local orng-light group coverage, upstream semantic hues and diff/diagnostic tints.
vim.cmd("hi clear")
vim.g.colors_name = "token-ultra-dark"
vim.o.termguicolors = true
vim.o.background = "dark"

local c = {
  bg = "#272724",
  bg_float = "#30302c",
  bg_popup = "#30302c",
  bg_sidebar = "#212120",
  bg_highlight = "#383835",
  bg_visual = "#3c3b36",
  bg_search = "#4d4231",
  bg_cursorline = "#30302c",
  fg = "#c5c1b8",
  fg_dim = "#a7a299",
  fg_muted = "#a39d94",
  fg_dark = "#8d8983",
  fg_gutter = "#585855",
  border = "#636360",
  control = "#f7c988",
  definition = "#ed9574",
  variable = "#c5c1b8",
  literal = "#78aba4",
  string_special = "#78aba4",
  property = "#c5c1b8",
  operator = "#a7a299",
  number = "#78aba4",
  type = "#a7a299",
  green = "#9ab58e",
  green_bright = "#a1c99e",
  comment = "#a39d94",
  predictive = "#8d8983",
  error = "#dd8384",
  warn = "#bf9c53",
  info = "#8aa5bb",
  hint = "#7ebcbb",
  diff_add = "#1e3524",
  diff_delete = "#3c2024",
  diff_change = "#2b2b29",
  diff_text = "#444039",
  git_add = "#7da47a",
  git_delete = "#c67777",
  git_change = "#c4a855",
  on_accent = "#181817",
  on_warm = "#181817",
  special = "#b296cb",
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
hi("IncSearch", { fg = c.on_warm, bg = c.control })
hi("CurSearch", { fg = c.on_warm, bg = c.control })
hi("Substitute", { fg = c.on_accent, bg = c.error })
hi("MatchParen", { fg = c.control })
hi("NonText", { fg = c.border })
hi("SpecialKey", { fg = c.border })
hi("Whitespace", { fg = c.border })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.info })
hi("Conceal", { fg = c.fg_dark })
hi("Title", { fg = c.definition, bold = true })
hi("ErrorMsg", { fg = c.error })
hi("WarningMsg", { fg = c.warn })
hi("ModeMsg", { fg = c.fg_dim, bold = true })
hi("MoreMsg", { fg = c.literal })
hi("Question", { fg = c.control })
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
hi("Constant", { fg = c.literal })
hi("String", { fg = c.literal })
hi("Character", { fg = c.literal })
hi("Number", { fg = c.number })
hi("Boolean", { fg = c.number })
hi("Float", { fg = c.number })
hi("Identifier", { fg = c.variable })
hi("Function", { fg = c.definition })
hi("Statement", { fg = c.control })
hi("Conditional", { fg = c.control })
hi("Repeat", { fg = c.control })
hi("Label", { fg = c.control })
hi("Operator", { fg = c.operator })
hi("Keyword", { fg = c.control })
hi("Exception", { fg = c.control })
hi("PreProc", { fg = c.control })
hi("Include", { fg = c.control })
hi("Define", { fg = c.control })
hi("Macro", { fg = c.control })
hi("PreCondit", { fg = c.control })
hi("Type", { fg = c.type })
hi("StorageClass", { fg = c.control })
hi("Structure", { fg = c.type })
hi("Typedef", { fg = c.type })
hi("Special", { fg = c.special })
hi("SpecialChar", { fg = c.special })
hi("Tag", { fg = c.type })
hi("Delimiter", { fg = c.operator })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.control })
hi("Underlined", { underline = true })
hi("Error", { fg = c.error })
hi("Todo", { fg = c.operator, bold = true })

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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#3c2024" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#444039" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#1e2634" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#1c2e2e" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.variable })
hi("@variable.builtin", { fg = c.type })
hi("@variable.parameter", { fg = c.operator })
hi("@variable.member", { fg = c.property })

hi("@constant", { fg = c.literal })
hi("@constant.builtin", { fg = c.literal })
hi("@constant.macro", { fg = c.control })

hi("@module", { fg = c.type })
hi("@label", { fg = c.control })

hi("@string", { fg = c.literal })
hi("@string.escape", { fg = c.literal })
hi("@string.regex", { fg = c.string_special })
hi("@string.special", { fg = c.string_special })

hi("@character", { fg = c.literal })
hi("@number", { fg = c.number })
hi("@boolean", { fg = c.number })
hi("@float", { fg = c.number })

hi("@function", { fg = c.definition })
hi("@function.builtin", { fg = c.type })
hi("@function.call", { fg = c.definition })
hi("@function.macro", { fg = c.control })
hi("@function.method", { fg = c.definition })
hi("@function.method.call", { fg = c.definition })

hi("@constructor", { fg = c.type })

hi("@operator", { fg = c.operator })

hi("@keyword", { fg = c.control })
hi("@keyword.coroutine", { fg = c.control })
hi("@keyword.function", { fg = c.control })
hi("@keyword.operator", { fg = c.control })
hi("@keyword.import", { fg = c.control })
hi("@keyword.return", { fg = c.control })
hi("@keyword.conditional", { fg = c.control })
hi("@keyword.repeat", { fg = c.control })
hi("@keyword.exception", { fg = c.control })

hi("@type", { fg = c.type })
hi("@type.builtin", { fg = c.type })
hi("@type.qualifier", { fg = c.control })
hi("@type.definition", { fg = c.definition })

hi("@property", { fg = c.property })
hi("@attribute", { fg = c.type })

hi("@punctuation.bracket", { fg = c.operator })
hi("@punctuation.delimiter", { fg = c.operator })
hi("@punctuation.special", { fg = c.operator })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.type })
hi("@tag.attribute", { fg = c.type })
hi("@tag.delimiter", { fg = c.comment })

hi("@markup.heading", { fg = c.definition, bold = true })
hi("@markup.italic", { italic = true })
hi("@markup.strong", { bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.info })
hi("@markup.link.url", { fg = c.info, underline = true })
hi("@markup.raw", { fg = c.literal })
hi("@markup.list", { fg = c.control })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.type })
hi("@lsp.type.interface", { fg = c.type })
hi("@lsp.type.keyword", { fg = c.control })
hi("@lsp.type.namespace", { fg = c.type })
hi("@lsp.type.parameter", { fg = c.operator })
hi("@lsp.type.property", { fg = c.property })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.type })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.type })

-- Telescope
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopeBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopeSelection", { bg = c.bg_visual })
hi("TelescopeSelectionCaret", { fg = c.control })
hi("TelescopeMatching", { fg = c.control })
hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_float })
hi("TelescopePromptBorder", { fg = c.border, bg = c.bg_float })
hi("TelescopePromptTitle", { fg = c.on_accent, bg = c.control })
hi("TelescopeResultsTitle", { fg = c.on_accent, bg = c.definition })
hi("TelescopePreviewTitle", { fg = c.on_accent, bg = c.operator })

-- Lazy
hi("LazyButton", { fg = c.fg, bg = c.bg_highlight })
hi("LazyButtonActive", { fg = c.on_accent, bg = c.control })
hi("LazyH1", { fg = c.on_accent, bg = c.control, bold = true })

-- WhichKey
hi("WhichKey", { fg = c.definition })
hi("WhichKeyGroup", { fg = c.control })
hi("WhichKeyDesc", { fg = c.fg_dim })
hi("WhichKeySeparator", { fg = c.fg_dark })
hi("WhichKeyFloat", { bg = c.bg_float })

-- Indent guides
hi("IndentBlanklineChar", { fg = "#333330", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#636360", nocombine = true })
hi("IblIndent", { fg = "#333330", nocombine = true })
hi("IblScope", { fg = "#636360", nocombine = true })

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
hi("NotifyTRACEBorder", { fg = c.definition })
hi("NotifyERRORTitle", { fg = c.error })
hi("NotifyWARNTitle", { fg = c.warn })
hi("NotifyINFOTitle", { fg = c.info })
hi("NotifyDEBUGTitle", { fg = c.fg_dark })
hi("NotifyTRACETitle", { fg = c.definition })


-- Ultra heading hierarchy and terminal palette from upstream.
hi("@markup.heading.1", { fg = "#ed9574", bold = true })
hi("@markup.heading.2", { fg = "#f7c988", bold = true })
hi("@markup.heading.3", { fg = "#8aa5bb", bold = true })
hi("@markup.heading.4", { fg = "#ed9574", bold = true })
hi("@markup.heading.5", { fg = "#f7c988", bold = true })
hi("@markup.heading.6", { fg = "#8aa5bb", bold = true })
vim.g.terminal_color_0 = "#1d1d1c"
vim.g.terminal_color_1 = "#dd8384"
vim.g.terminal_color_2 = "#9ab58e"
vim.g.terminal_color_3 = "#bf9c53"
vim.g.terminal_color_4 = "#8aa5bb"
vim.g.terminal_color_5 = "#b296cb"
vim.g.terminal_color_6 = "#7ebcbb"
vim.g.terminal_color_7 = "#a7a299"
vim.g.terminal_color_8 = "#8d8983"
vim.g.terminal_color_9 = "#ed9574"
vim.g.terminal_color_10 = "#a1c99e"
vim.g.terminal_color_11 = "#f7c988"
vim.g.terminal_color_12 = "#90b2cc"
vim.g.terminal_color_13 = "#bea5d4"
vim.g.terminal_color_14 = "#88c0c0"
vim.g.terminal_color_15 = "#c5c1b8"
hi("SnacksPickerPathHidden", { fg = c.fg_muted })
hi("SnacksPickerPathIgnored", { fg = c.fg_muted })
hi("SnacksPickerTotals", { fg = c.fg_muted })
hi("SnacksPickerUntracked", { fg = c.fg_muted })
hi("@number.float", { fg = c.number })
hi("@string.regexp", { fg = c.literal })

-- BSD 3-Clause License
--
-- Copyright (c) 2026, Thorsten Rhau
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its
--    contributors may be used to endorse or promote products derived from
--    this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

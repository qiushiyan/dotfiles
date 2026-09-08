-- Token Meridian Light — https://github.com/ThorstenRhau/token, revision 11be57ef6913
-- Palette: lua/token/palettes/meridian.lua; syntax: appearances/meridian_roles.lua.
-- Local orng-light group coverage, upstream semantic hues and diff/diagnostic tints.
vim.cmd("hi clear")
vim.g.colors_name = "token-meridian-light"
vim.o.termguicolors = true
vim.o.background = "light"

local c = {
  bg = "#fbf9f4",
  bg_float = "#f6f5f1",
  bg_popup = "#f6f5f1",
  bg_sidebar = "#ecebe7",
  bg_highlight = "#eae9e5",
  bg_visual = "#dedbd3",
  bg_search = "#eadab6",
  bg_cursorline = "#eae9e5",
  fg = "#28323a",
  fg_dim = "#46535f",
  fg_muted = "#524b42",
  fg_dark = "#43505c",
  fg_gutter = "#b5b2ab",
  border = "#e0ddd8",
  accent = "#0048b3",
  brick = "#7a1f7a",
  red = "#28323a",
  blue = "#005f2f",
  blue_deep = "#7a1f7a",
  blue_soft = "#4b1fa3",
  teal = "#46535f",
  teal_bright = "#095b62",
  gold = "#843900",
  green = "#005f2f",
  green_bright = "#24831f",
  comment = "#524b42",
  predictive = "#43505c",
  error = "#286fc0",
  warn = "#2f75c6",
  info = "#0048b3",
  hint = "#095b62",
  diff_add = "#daf6d5",
  diff_delete = "#ffdada",
  diff_change = "#eee4c6",
  diff_text = "#e2dac0",
  git_add = "#24831f",
  git_delete = "#c82a2a",
  git_change = "#9d6600",
  on_accent = "#fbf9f4",
  on_warm = "#fbf9f4",
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
hi("Substitute", { fg = c.on_accent, bg = c.error })
hi("MatchParen", { fg = c.accent, bold = true })
hi("NonText", { fg = c.border })
hi("SpecialKey", { fg = c.border })
hi("Whitespace", { fg = c.border })
hi("EndOfBuffer", { fg = c.bg })
hi("Directory", { fg = c.accent })
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
hi("Constant", { fg = c.blue })
hi("String", { fg = c.blue })
hi("Character", { fg = c.blue })
hi("Number", { fg = c.teal_bright })
hi("Boolean", { fg = c.teal_bright })
hi("Float", { fg = c.teal_bright })
hi("Identifier", { fg = c.red })
hi("Function", { fg = c.brick })
hi("Statement", { fg = c.accent, bold = true })
hi("Conditional", { fg = c.accent, bold = true })
hi("Repeat", { fg = c.accent, bold = true })
hi("Label", { fg = c.accent, bold = true })
hi("Operator", { fg = c.teal })
hi("Keyword", { fg = c.accent, bold = true })
hi("Exception", { fg = c.accent, bold = true })
hi("PreProc", { fg = c.accent, bold = true })
hi("Include", { fg = c.accent, bold = true })
hi("Define", { fg = c.accent, bold = true })
hi("Macro", { fg = c.accent, bold = true })
hi("PreCondit", { fg = c.accent, bold = true })
hi("Type", { fg = c.gold })
hi("StorageClass", { fg = c.accent, bold = true })
hi("Structure", { fg = c.gold })
hi("Typedef", { fg = c.gold })
hi("Special", { fg = c.brick })
hi("SpecialChar", { fg = c.brick })
hi("Tag", { fg = c.accent })
hi("Delimiter", { fg = c.teal })
hi("SpecialComment", { fg = c.comment, italic = true })
hi("Debug", { fg = c.accent, bold = true })
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
hi("DiagnosticVirtualTextError", { fg = c.error, bg = "#ffdada" })
hi("DiagnosticVirtualTextWarn", { fg = c.warn, bg = "#e2dac0" })
hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = "#dae4f2" })
hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = "#d6eeea" })

-- Git signs
hi("GitSignsAdd", { fg = c.git_add })
hi("GitSignsChange", { fg = c.git_change })
hi("GitSignsDelete", { fg = c.git_delete })

-- Treesitter
hi("@variable", { fg = c.red })
hi("@variable.builtin", { fg = c.gold })
hi("@variable.parameter", { fg = c.teal })
hi("@variable.member", { fg = c.blue_soft })

hi("@constant", { fg = c.blue })
hi("@constant.builtin", { fg = c.blue })
hi("@constant.macro", { fg = c.accent, bold = true })

hi("@module", { fg = c.gold })
hi("@label", { fg = c.accent, bold = true })

hi("@string", { fg = c.blue })
hi("@string.escape", { fg = c.brick })
hi("@string.regex", { fg = c.blue_deep })
hi("@string.special", { fg = c.blue_deep })

hi("@character", { fg = c.blue })
hi("@number", { fg = c.teal_bright })
hi("@boolean", { fg = c.teal_bright })
hi("@float", { fg = c.teal_bright })

hi("@function", { fg = c.brick })
hi("@function.builtin", { fg = c.gold })
hi("@function.call", { fg = c.brick })
hi("@function.macro", { fg = c.accent, bold = true })
hi("@function.method", { fg = c.brick })
hi("@function.method.call", { fg = c.brick })

hi("@constructor", { fg = c.brick })

hi("@operator", { fg = c.teal })

hi("@keyword", { fg = c.accent, bold = true })
hi("@keyword.coroutine", { fg = c.accent, bold = true })
hi("@keyword.function", { fg = c.accent, bold = true })
hi("@keyword.operator", { fg = c.accent, bold = true })
hi("@keyword.import", { fg = c.accent, bold = true })
hi("@keyword.return", { fg = c.accent, bold = true })
hi("@keyword.conditional", { fg = c.accent, bold = true })
hi("@keyword.repeat", { fg = c.accent, bold = true })
hi("@keyword.exception", { fg = c.accent, bold = true })

hi("@type", { fg = c.gold })
hi("@type.builtin", { fg = c.gold })
hi("@type.qualifier", { fg = c.accent, bold = true })
hi("@type.definition", { fg = c.brick })

hi("@property", { fg = c.blue_soft })
hi("@attribute", { fg = c.gold })

hi("@punctuation.bracket", { fg = c.teal })
hi("@punctuation.delimiter", { fg = c.teal })
hi("@punctuation.special", { fg = c.accent })

hi("@comment", { fg = c.comment, italic = true })

hi("@tag", { fg = c.accent })
hi("@tag.attribute", { fg = c.gold })
hi("@tag.delimiter", { fg = c.teal })

hi("@markup.heading", { fg = c.accent, bold = true })
hi("@markup.italic", { fg = c.gold, italic = true })
hi("@markup.strong", { fg = c.accent, bold = true })
hi("@markup.strikethrough", { strikethrough = true })
hi("@markup.link", { fg = c.accent })
hi("@markup.link.url", { fg = c.accent })
hi("@markup.raw", { fg = c.blue })
hi("@markup.list", { fg = c.accent })

-- LSP semantic tokens
hi("@lsp.type.comment", {})
hi("@lsp.type.enum", { fg = c.red })
hi("@lsp.type.interface", { fg = c.brick })
hi("@lsp.type.keyword", { fg = c.accent, bold = true })
hi("@lsp.type.namespace", { fg = c.gold })
hi("@lsp.type.parameter", { fg = c.teal })
hi("@lsp.type.property", { fg = c.blue_soft })
hi("@lsp.type.variable", {})
hi("@lsp.typemod.function.defaultLibrary", { fg = c.gold })
hi("@lsp.typemod.variable.defaultLibrary", { fg = c.gold })

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
hi("IndentBlanklineChar", { fg = "#e0ddd8", nocombine = true })
hi("IndentBlanklineContextChar", { fg = "#a8a49c", nocombine = true })
hi("IblIndent", { fg = "#e0ddd8", nocombine = true })
hi("IblScope", { fg = "#a8a49c", nocombine = true })

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

-- Meridian heading hierarchy and terminal palette from upstream.
hi("@markup.heading.1", { fg = "#1c4470", bold = true })
hi("@markup.heading.2", { fg = "#20538a", bold = true })
hi("@markup.heading.3", { fg = "#1c60a2", bold = true })
hi("@markup.heading.4", { fg = "#236bb5", bold = true })
hi("@markup.heading.5", { fg = "#286fc0", bold = true })
hi("@markup.heading.6", { fg = "#2f75c6", bold = true })
vim.g.terminal_color_0 = "#28323a"
vim.g.terminal_color_1 = "#843900"
vim.g.terminal_color_2 = "#005f2f"
vim.g.terminal_color_3 = "#843900"
vim.g.terminal_color_4 = "#0048b3"
vim.g.terminal_color_5 = "#7a1f7a"
vim.g.terminal_color_6 = "#095b62"
vim.g.terminal_color_7 = "#b5b2ab"
vim.g.terminal_color_8 = "#524b42"
vim.g.terminal_color_9 = "#843900"
vim.g.terminal_color_10 = "#005f2f"
vim.g.terminal_color_11 = "#843900"
vim.g.terminal_color_12 = "#0048b3"
vim.g.terminal_color_13 = "#4b1fa3"
vim.g.terminal_color_14 = "#095b62"
vim.g.terminal_color_15 = "#fbf9f4"
hi("SnacksPickerPathHidden", { fg = c.fg_muted })
hi("SnacksPickerPathIgnored", { fg = c.fg_muted })
hi("SnacksPickerTotals", { fg = c.fg_muted })
hi("SnacksPickerUntracked", { fg = c.fg_muted })

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

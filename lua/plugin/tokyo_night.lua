-- Tokyo Night inspired color theme for Neovim
-- Save this file as: ~/.config/nvim/colors/tokyo_night.lua
-- To use: :colorscheme tokyo_night

vim.cmd('highlight clear')
if vim.fn.exists('syntax_on') then
  vim.cmd('syntax reset')
end

vim.g.colors_name = 'tokyo_night'
vim.o.background = 'dark'

-- Color palette
local colors = {
  bg = '#1a1b26',
  bg_dark = '#16161e',
  bg_highlight = '#292e42',
  terminal_black = '#414868',
  fg = '#c0caf5',
  fg_dark = '#a9b1d6',
  fg_gutter = '#3b4261',
  dark3 = '#545c7e',
  comment = '#565f89',
  dark5 = '#737aa2',
  blue0 = '#3d59a1',
  blue = '#7aa2f7',
  cyan = '#7dcfff',
  blue1 = '#2ac3de',
  blue2 = '#0db9d7',
  blue5 = '#89ddff',
  blue6 = '#b4f9f8',
  blue7 = '#394b70',
  magenta = '#bb9af7',
  magenta2 = '#ff007c',
  purple = '#9d7cd8',
  orange = '#ff9e64',
  yellow = '#e0af68',
  green = '#9ece6a',
  green1 = '#73daca',
  green2 = '#41a6b5',
  teal = '#1abc9c',
  red = '#f7768e',
  red1 = '#db4b4b',
  git_add = '#449dab',
  git_change = '#6183bb',
  git_delete = '#914c54',
}

-- Helper function to set highlights
local function hi(group, opts)
  local command = 'highlight ' .. group
  if opts.fg then command = command .. ' guifg=' .. opts.fg end
  if opts.bg then command = command .. ' guibg=' .. opts.bg end
  if opts.sp then command = command .. ' guisp=' .. opts.sp end
  if opts.style then command = command .. ' gui=' .. opts.style end
  vim.cmd(command)
end

-- Editor highlights
hi('Normal', { fg = colors.fg, bg = colors.bg })
hi('NormalFloat', { fg = colors.fg, bg = colors.bg_dark })
hi('NormalNC', { fg = colors.fg, bg = colors.bg })
hi('LineNr', { fg = colors.fg_gutter })
hi('CursorLine', { bg = colors.bg_highlight })
hi('CursorLineNr', { fg = colors.dark5 })
hi('Visual', { bg = colors.bg_highlight })
hi('VisualNOS', { bg = colors.bg_highlight })
hi('Search', { bg = colors.blue0, fg = colors.fg })
hi('IncSearch', { bg = colors.orange, fg = colors.bg })
hi('CurSearch', { bg = colors.orange, fg = colors.bg })
hi('Cursor', { fg = colors.bg, bg = colors.fg })
hi('ColorColumn', { bg = colors.bg_dark })
hi('SignColumn', { fg = colors.fg_gutter, bg = colors.bg })
hi('Conceal', { fg = colors.dark5 })
hi('CursorColumn', { bg = colors.bg_highlight })
hi('VertSplit', { fg = colors.bg_highlight })
hi('WinSeparator', { fg = colors.bg_highlight })
hi('Folded', { fg = colors.blue, bg = colors.fg_gutter })
hi('FoldColumn', { fg = colors.comment, bg = colors.bg })
hi('MatchParen', { fg = colors.orange, style = 'bold' })
hi('Pmenu', { fg = colors.fg, bg = colors.bg_dark })
hi('PmenuSel', { bg = colors.bg_highlight })
hi('PmenuSbar', { bg = colors.bg_highlight })
hi('PmenuThumb', { bg = colors.fg_gutter })

-- Statusline
hi('StatusLine', { fg = colors.fg, bg = colors.bg_dark })
hi('StatusLineNC', { fg = colors.fg_gutter, bg = colors.bg_dark })
hi('TabLine', { fg = colors.fg_gutter, bg = colors.bg_dark })
hi('TabLineFill', { bg = colors.bg_dark })
hi('TabLineSel', { fg = colors.fg, bg = colors.blue })

-- Syntax highlighting
hi('Comment', { fg = colors.comment, style = 'italic' })
hi('Constant', { fg = colors.orange })
hi('String', { fg = colors.green })
hi('Character', { fg = colors.green })
hi('Number', { fg = colors.orange })
hi('Boolean', { fg = colors.orange })
hi('Float', { fg = colors.orange })
hi('Identifier', { fg = colors.magenta })
hi('Function', { fg = colors.blue })
hi('Statement', { fg = colors.magenta })
hi('Conditional', { fg = colors.magenta })
hi('Repeat', { fg = colors.magenta })
hi('Label', { fg = colors.red })
hi('Operator', { fg = colors.blue5 })
hi('Keyword', { fg = colors.cyan, style = 'italic' })
hi('Exception', { fg = colors.magenta })
hi('PreProc', { fg = colors.cyan })
hi('Include', { fg = colors.magenta })
hi('Define', { fg = colors.magenta })
hi('Macro', { fg = colors.magenta })
hi('PreCondit', { fg = colors.magenta })
hi('Type', { fg = colors.blue1 })
hi('StorageClass', { fg = colors.magenta })
hi('Structure', { fg = colors.cyan })
hi('Typedef', { fg = colors.cyan })
hi('Special', { fg = colors.blue1 })
hi('SpecialChar', { fg = colors.yellow })
hi('Tag', { fg = colors.red })
hi('Delimiter', { fg = colors.fg_dark })
hi('SpecialComment', { fg = colors.dark5 })
hi('Debug', { fg = colors.orange })
hi('Underlined', { style = 'underline' })
hi('Ignore', { fg = colors.dark5 })
hi('Error', { fg = colors.red })
hi('Todo', { fg = colors.blue, bg = colors.yellow })

-- Treesitter highlights
hi('TSAnnotation', { fg = colors.yellow })
hi('TSAttribute', { fg = colors.cyan })
hi('TSBoolean', { fg = colors.orange })
hi('TSCharacter', { fg = colors.green })
hi('TSComment', { fg = colors.comment, style = 'italic' })
hi('TSConditional', { fg = colors.magenta })
hi('TSConstant', { fg = colors.orange })
hi('TSConstBuiltin', { fg = colors.orange })
hi('TSConstMacro', { fg = colors.orange })
hi('TSConstructor', { fg = colors.blue1 })
hi('TSException', { fg = colors.magenta })
hi('TSField', { fg = colors.green1 })
hi('TSFloat', { fg = colors.orange })
hi('TSFunction', { fg = colors.blue })
hi('TSFuncBuiltin', { fg = colors.cyan })
hi('TSFuncMacro', { fg = colors.blue })
hi('TSInclude', { fg = colors.magenta })
hi('TSKeyword', { fg = colors.cyan, style = 'italic' })
hi('TSKeywordFunction', { fg = colors.magenta })
hi('TSKeywordOperator', { fg = colors.cyan })
hi('TSLabel', { fg = colors.blue })
hi('TSMethod', { fg = colors.blue })
hi('TSNamespace', { fg = colors.cyan })
hi('TSNumber', { fg = colors.orange })
hi('TSOperator', { fg = colors.blue5 })
hi('TSParameter', { fg = colors.yellow })
hi('TSParameterReference', { fg = colors.yellow })
hi('TSProperty', { fg = colors.green1 })
hi('TSPunctDelimiter', { fg = colors.blue5 })
hi('TSPunctBracket', { fg = colors.fg_dark })
hi('TSPunctSpecial', { fg = colors.blue5 })
hi('TSRepeat', { fg = colors.magenta })
hi('TSString', { fg = colors.green })
hi('TSStringRegex', { fg = colors.blue6 })
hi('TSStringEscape', { fg = colors.magenta })
hi('TSSymbol', { fg = colors.cyan })
hi('TSTag', { fg = colors.red })
hi('TSTagDelimiter', { fg = colors.blue5 })
hi('TSText', { fg = colors.fg })
hi('TSStrong', { style = 'bold' })
hi('TSEmphasis', { style = 'italic' })
hi('TSUnderline', { style = 'underline' })
hi('TSStrike', { style = 'strikethrough' })
hi('TSTitle', { fg = colors.blue, style = 'bold' })
hi('TSLiteral', { fg = colors.green })
hi('TSURI', { fg = colors.cyan, style = 'underline' })
hi('TSMath', { fg = colors.blue })
hi('TSTextReference', { fg = colors.teal })
hi('TSEnvironment', { fg = colors.magenta })
hi('TSEnvironmentName', { fg = colors.yellow })
hi('TSNote', { fg = colors.bg, bg = colors.blue })
hi('TSWarning', { fg = colors.bg, bg = colors.yellow })
hi('TSDanger', { fg = colors.bg, bg = colors.red })
hi('TSType', { fg = colors.blue1 })
hi('TSTypeBuiltin', { fg = colors.cyan })
hi('TSVariable', { fg = colors.fg })
hi('TSVariableBuiltin', { fg = colors.red })

-- LSP highlights
hi('LspReferenceText', { bg = colors.fg_gutter })
hi('LspReferenceRead', { bg = colors.fg_gutter })
hi('LspReferenceWrite', { bg = colors.fg_gutter })
hi('DiagnosticError', { fg = colors.red })
hi('DiagnosticWarn', { fg = colors.yellow })
hi('DiagnosticInfo', { fg = colors.blue })
hi('DiagnosticHint', { fg = colors.cyan })
hi('DiagnosticUnderlineError', { sp = colors.red, style = 'underline' })
hi('DiagnosticUnderlineWarn', { sp = colors.yellow, style = 'underline' })
hi('DiagnosticUnderlineInfo', { sp = colors.blue, style = 'underline' })
hi('DiagnosticUnderlineHint', { sp = colors.cyan, style = 'underline' })

-- Git signs
hi('GitSignsAdd', { fg = colors.git_add })
hi('GitSignsChange', { fg = colors.git_change })
hi('GitSignsDelete', { fg = colors.git_delete })
hi('DiffAdd', { bg = colors.git_add, fg = colors.bg })
hi('DiffChange', { bg = colors.git_change, fg = colors.bg })
hi('DiffDelete', { bg = colors.git_delete, fg = colors.bg })
hi('DiffText', { bg = colors.blue, fg = colors.bg })

-- Telescope
hi('TelescopeBorder', { fg = colors.blue7, bg = colors.bg_dark })
hi('TelescopeNormal', { fg = colors.fg, bg = colors.bg_dark })
hi('TelescopeSelection', { fg = colors.fg, bg = colors.bg_highlight })
hi('TelescopeSelectionCaret', { fg = colors.cyan, bg = colors.bg_highlight })
hi('TelescopeMultiSelection', { fg = colors.magenta, bg = colors.bg_highlight })
hi('TelescopeMatching', { fg = colors.blue, style = 'bold' })

-- Terminal colors
vim.g.terminal_color_0 = colors.terminal_black
vim.g.terminal_color_1 = colors.red
vim.g.terminal_color_2 = colors.green
vim.g.terminal_color_3 = colors.yellow
vim.g.terminal_color_4 = colors.blue
vim.g.terminal_color_5 = colors.magenta
vim.g.terminal_color_6 = colors.cyan
vim.g.terminal_color_7 = colors.fg
vim.g.terminal_color_8 = colors.dark5
vim.g.terminal_color_9 = colors.red
vim.g.terminal_color_10 = colors.green
vim.g.terminal_color_11 = colors.yellow
vim.g.terminal_color_12 = colors.blue
vim.g.terminal_color_13 = colors.magenta
vim.g.terminal_color_14 = colors.cyan
vim.g.terminal_color_15 = colors.fg

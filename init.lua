if vim.fn.has("nvim-0.11") == 0 then
    vim.notify("NativeVim only supports Neovim 0.11+", vim.log.levels.ERROR)
    return
end

require('core.options')
require("core.treesitter")
require("core.lsp")
require("core.statusline")
require('plugin.tokyo_night')

-- custom plugins
require("plugin.gitchange").setup()
-- Load the fuzzy finder module
local fuzzy_finder = require('plugin.fuzzy_finder')

-- Set up the keybinding (assuming <leader> is space or your preferred leader key)
vim.keymap.set('n', '<leader>fs', fuzzy_finder.show, { desc = 'Fuzzy find files' })

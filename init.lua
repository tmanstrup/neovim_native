if vim.fn.has("nvim-0.11") == 0 then
    vim.notify("NativeVim only supports Neovim 0.11+", vim.log.levels.ERROR)
    return
end

require('core.options')
require("core.treesitter")
require("core.lsp")
require("core.statusline")

-- custom plugins
require("plugin.gitchange").setup()
--require("plugin.file-search2").setup()
--require("plugin.textwatcher").setup({attach = true})

--local logfile = "/tmp/nvim_notify.log"
--
--vim.notify = function(msg, level, opts)
--  local f = io.open(logfile, "a")
--  f:write(msg .. "\n")
--  f:close()
--end

-- Expose :BufferBanner command
--vim.api.nvim_create_user_command("BufferBanner", function()
--  require("plugin.banner").open_banner()
--end, {})
--
---- Automatically update the banner when buffers change
--vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter" }, {
--  callback = function()
--    require("plugin.banner").refresh_if_open()
--  end,
--})

--require('plugin.banner2').setup()
--require('plugin.banner2').setup({
--  height = 1,                        -- Banner height
--  separator = ' | ',                 -- Separator between buffers
--  current_buf_hl = 'TabLineSel',    -- Highlight for current buffer
--  other_buf_hl = 'TabLine',         -- Highlight for other buffers
--  modified_indicator = '[+]',        -- Indicator for modified buffers
--})
--
--vim.keymap.set('n', '<leader>bt', '<cmd>lua require("banner2").toggle()<cr>', 
--  { desc = 'Toggle buffer banner' })
--
-- Add to your init.lua or init.vim (wrapped in lua << EOF ... EOF)

-- Load the fuzzy finder module
local fuzzy_finder = require('plugin.fuzzy_finder')

-- Set up the keybinding (assuming <leader> is space or your preferred leader key)
vim.keymap.set('n', '<leader>fs', fuzzy_finder.show, { desc = 'Fuzzy find files' })

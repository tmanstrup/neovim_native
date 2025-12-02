-- :h lsp-config

-- enable lsp completion
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
    callback = function(ev)
        vim.lsp.completion.enable(true, ev.data.client_id, ev.buf)
		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
		if client:supports_method('textDocument/completion') then
      		-- Optional: trigger autocompletion on EVERY keypress. May be slow!
      		-- local chars = {}; for i = 32, 126 do table.insert(chars, string.char(i)) end
      		-- client.server_capabilities.completionProvider.triggerCharacters = chars
      		vim.lsp.completion.enable(true, client.id, ev.buf, {autotrigger = true})
    	end
    end,
})

-- enable configured language servers
-- you can find server configurations from lsp/*.lua files
vim.lsp.enable('gopls')
vim.lsp.enable('lua_ls')
vim.lsp.enable('ts_ls')
vim.lsp.enable('clangd_ls')

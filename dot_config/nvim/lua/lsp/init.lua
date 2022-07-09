local opts = { noremap=true, silent=true }

local on_attach = function(client, bufnr)
	-- Enable completion triggered by <c-x><c-o>
	vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

	vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
	vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
	vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
	vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
end

local lsp_capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
require('lspconfig').gopls.setup {
	cmd = {'gopls', '-remote=auto'},
	on_attach = on_attach,
	flags = {
		-- Don't spam LSP with changes. Wait a second between each
		debounce_text_changes = 1000,
	},
	init_options = {
		staticcheck = true,
		gofumpt = true,
		memoryMode = "DegradeClosed",
	},
	capabilites = lsp_capabilities,
}

function FormatAndImports(wait_ms)
    vim.lsp.buf.format(nil, wait_ms)
    local params = vim.lsp.util.make_range_params()
    params.context = {only = {“source.organizeImports”}}
    local result = vim.lsp.buf_request_sync(0, “textDocument/codeAction”, params, wait_ms)
    for _, res in pairs(result or {}) do
        for _, r in pairs(res.result or {}) do
            if r.edit then
                vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
            else
                vim.lsp.buf.execute_command(r.command)
            end
        end
    end
end


vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.go",
	callback = function(args)
		goFormatAndImports(3000)
	end,
})

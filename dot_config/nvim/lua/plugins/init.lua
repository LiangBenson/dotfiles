local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
	packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

vim.cmd [[packadd packer.nvim]]

local ok, packer = pcall(require, "packer")
if not ok then
    return
end

packer.init {
    display = {
        open_fn = function()
            return require("packer.util").float { border = "single" }
        end,
        prompt_border = "single",
    },
    git = {
        clone_timeout = 600,
    },
    auto_clean = true,
    compile_on_sync = true,
}

return require('packer').startup(function(use)
	use {"wbthomason/packer.nvim"}

	-- THEME
	use {"morhetz/gruvbox"}

	-- COMPLETION
	use {"hrsh7th/nvim-cmp"}
	use {"hrsh7th/cmp-nvim-lsp"}

	-- LSP
	use {
		"fatih/vim-go",
		config = function()
			require "plugins.configs.vimgo"
		end
	}
	use {"nvim-lspconfig"}

	-- Automatically set up your configuration after cloning packer.nvim
	-- Put this at the end after all plugins
	if packer_bootstrap then
		require('packer').sync()
	end
end)

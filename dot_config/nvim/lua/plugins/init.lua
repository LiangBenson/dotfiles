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
	use {"ryanoasis/vim-devicons"}
	use {"kyazdani42/nvim-web-devicons"}

	-- COMPLETION
	use {"hrsh7th/cmp-nvim-lsp"}
	use {
		"hrsh7th/nvim-cmp",
		requires = {
			"hrsh7th/cmp-nvim-lsp",
			"quangnguyen30192/cmp-nvim-ultisnips",
			"honza/vim-snippets",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-cmdline",
			"SirVer/ultisnips",
		},
		config = function()
			require "plugins.configs.cmp"
		end,
	}

	-- GIT
	use {"rhysd/git-messenger.vim"}

	-- LSP
	use {
		"fatih/vim-go",
		config = function()
			require "plugins.configs.vimgo"
		end
	}
	use {"neovim/nvim-lspconfig"}

	-- UTIL
	use {
		'nvim-telescope/telescope.nvim',
		requires = { {'nvim-lua/plenary.nvim'} },
		config = function()
			require "plugins.configs.telescope"
		end,
	}
	use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
	use {
		"windwp/nvim-autopairs",
		config = function() require("nvim-autopairs").setup {} end
	}
	use {
	  "folke/trouble.nvim",
	  requires = "kyazdani42/nvim-web-devicons",
	}
	use {
	  'kyazdani42/nvim-tree.lua',
	  require = {
		'kyazdani42/nvim-web-devicons', -- optional, for file icons
	  },
	  config = function() require "plugins.configs.nvimtree" end,
	}
	use {
		"feline-nvim/feline.nvim",
		config = function() require "plugins.configs.feline" end,
	}
	use {
        "folke/which-key.nvim",
    }
	use {
		'numToStr/Comment.nvim',
		config = function()
			require('Comment').setup()
		end
	}

	-- Automatically set up your configuration after cloning packer.nvim
	-- Put this at the end after all plugins
	if packer_bootstrap then
		require('packer').sync()
	end
end)

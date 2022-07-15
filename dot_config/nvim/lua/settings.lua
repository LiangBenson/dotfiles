vim.env.PATH = vim.env.VIM_PATH or vim.env.PATH

vim.g.mapleader = " "

vim.opt.wrap            = true
vim.opt.swapfile        = false
vim.opt.hlsearch        = false
vim.opt.incsearch       = true
vim.opt.splitbelow      = true
vim.opt.splitright      = true
vim.opt.number          = true
vim.opt.relativenumber  = true
vim.opt.tabstop         = 4
vim.opt.softtabstop     = 4
vim.opt.shiftwidth      = 4
vim.opt.autoindent      = true
vim.opt.autowrite       = true
vim.opt.termguicolors   = true

vim.cmd('syntax enable')
vim.cmd('colorscheme gruvbox')

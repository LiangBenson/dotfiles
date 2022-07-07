vim.g.mapleader = " "

vim.api.nvim_set_keymap('n', '<leader>w', ':w<CR>', {noremap=true, silent=true})
vim.api.nvim_set_keymap('n', '<c-p', '<cmd>lua require("telescope.builtin").find_files()<cr>', {noremap=true, silent=true})

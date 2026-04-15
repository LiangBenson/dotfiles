local map = vim.keymap.set
local silent = { silent = true }

map("i", "jj", "<Esc>", silent)

map("n", "<leader>w", "<cmd>write<CR>", silent)
map("n", "<leader>q", "<cmd>quit<CR>", silent)
map("n", "<leader>x", "<cmd>wq<CR>", silent)
map("n", "<Esc>", "<cmd>nohlsearch<CR>", silent)
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", silent)
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", silent)
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", silent)
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", silent)

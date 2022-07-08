local _telescope, telescope = pcall(require, "telescope")
if not _telescope then
	return
end

local actions = require "telescope.actions"

telescope.setup {
	defaults = {
		mappings = {
			i = {
				["<c-j>"] = "move_selection_next",
				["<c-k>"] = "move_selection_previous",
			},
			n = {
				["<c-j>"] = "move_selection_next",
				["<c-k>"] = "move_selection_previous",
			},
		},
	},
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		}
	}
}

telescope.load_extension('fzf')

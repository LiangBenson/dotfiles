local  _nvimtree, nvimtree = pcall(require, “nvim-tree”)
if not _nvimtree then
	return
end

nvimtree.setup({
	sort_by = “case_sensitive”,
	view = {
		adaptive_size = true,
		mappings = {
			list = {
				{ key = “u”, action = “dir_up” },
			},
		},
	},
	renderer = {
		group_empty = true,
	},
	filters = {
		dotfiles = true,
	},
})

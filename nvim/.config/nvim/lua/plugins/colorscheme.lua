return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      -- Frappé, the same palette as Ghostty and the tmux status bar.
      require("catppuccin").setup({ flavour = "frappe" })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}

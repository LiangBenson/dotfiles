return {
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- Compiling parsers needs the tree-sitter CLI and a C compiler
      -- (bootstrap.sh installs both where it can). Without them, Neovim's
      -- built-in parsers and regular syntax highlighting still work.
      if vim.fn.executable("tree-sitter") == 1 and vim.fn.executable("cc") == 1 then
        local install = require("nvim-treesitter").install({
          "bash",
          "lua",
          "markdown",
          "markdown_inline",
          "query",
          "vim",
          "vimdoc",
        })
        -- Installs in the background (no-op once installed). Headless runs,
        -- like the one in bootstrap.sh, wait for it instead.
        if #vim.api.nvim_list_uis() == 0 then
          install:wait(300000)
        end
      end

      -- Treesitter highlighting and indent wherever a parser exists; other
      -- files keep Vim's regular syntax highlighting.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(event)
          if pcall(vim.treesitter.start, event.buf) then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
}

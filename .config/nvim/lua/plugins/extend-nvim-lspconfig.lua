return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      require("lspconfig").protols.setup({})
    end,
  },
}

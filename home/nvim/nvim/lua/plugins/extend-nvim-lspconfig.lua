return {
  {
    "neovim/nvim-lspconfig",
    -- opts = function()
    --   require("lspconfig").protols.setup({})
    -- end,
    opts = {
      servers = {
        protols = {},
        gopls = {
          mason = false, -- use binary from PATH
          settings = {
            gopls = {
              usePlaceholders = false,
            },
          },
        },
        nil_ls = {},
        nixd = {},
      },
      setup = {
        gopls = function(_, _)
          LazyVim.lsp.on_attach(function()
            vim.api.nvim_set_hl(0, "@lsp.type.string.go", {})
          end, "gopls")
        end,
      },
    },
  },
}

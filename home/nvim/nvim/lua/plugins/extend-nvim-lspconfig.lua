return {
  {
    "neovim/nvim-lspconfig",
    -- opts = function()
    --   require("lspconfig").protols.setup({})
    -- end,
    opts = {
      servers = {
        buf_ls = {},
        gopls = {
          mason = false, -- use binary from PATH
          settings = {
            gopls = {
              usePlaceholders = false,
            },
          },
        },
        golangci_lint_ls = {
          enabled = true,
          init_options = {
            -- override command because default nvim-lspconfig config now use command for golangci-lint v2
            -- command = { "golangci-lint", "run", "--out-format", "json", "--issues-exit-code=1" },
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

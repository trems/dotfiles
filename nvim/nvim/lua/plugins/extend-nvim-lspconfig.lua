return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      codelens = {
        enabled = true,
      },
      servers = {
        buf_ls = {},
        gopls = {
          mason = false, -- use binary from PATH
          settings = {
            gopls = {
              renameMovesSubpackages = true,
              hoverKind = "FullDocumentation",
              completeUnimported = true,
              usePlaceholders = false,
              analyses = {
                ["ST1000"] = false, -- package comments
              },
              hints = {
                ["ignoredError"] = true,
              },
            },
          },
        },
        golangci_lint_ls = {
          enabled = false,
          init_options = {
            -- override command because default nvim-lspconfig config now use command for golangci-lint v2
            -- command = { "golangci-lint", "run", "--out-format", "json", "--issues-exit-code=1" },
          },
        },
      },
      setup = {
        gopls = function(_, _)
          Snacks.util.lsp.on({ name = "gopls" }, function()
            vim.api.nvim_set_hl(0, "@lsp.type.string.go", {})
          end)
        end,
      },
    },
  },
}

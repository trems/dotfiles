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
        nixd = {]
                      nixpkgs = {
                -- For flake.
                -- This expression will be interpreted as "nixpkgs" toplevel
                -- Nixd provides package, lib completion/information from it.
                -- Resource Usage: Entries are lazily evaluated, entire nixpkgs takes 200~300MB for just "names".
                -- Package documentation, versions, are evaluated by-need.
                expr = "import (builtins.getFlake(toString ./.)).inputs.nixpkgs { }",
            },
            formatting = {
                command = { "alejandra" }, -- or nixfmt or nixpkgs-fmt
            },
        },
        clangd = {
          filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- exclude "proto"
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

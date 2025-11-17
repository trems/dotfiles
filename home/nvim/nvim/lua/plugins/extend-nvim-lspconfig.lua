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
        nixd = {
          settings = {
            nixd = {
              -- from https://sbulav.github.io/vim/neovim-setting-up-nixd/
              nixpkgs = {
                expr = "import (builtins.getFlake(toString ./.)).inputs.nixpkgs { }",
              },
              formatting = {
                command = { "alejandra" },
              },
              options = {
                nixos = {
                  expr = "(builtins.getFlake(toString ./.)) in flake.nixosConfigurations.nz.options",
                },
                home_manager = {
                  expr = 'let flake = builtins.getFlake(toString ./.); in flake.darwinConfigurations."IT-MAC-NB165".options.home-manager',
                },
                darwin = {
                  expr = 'let flake = builtins.getFlake(toString ./.); in flake.darwinConfigurations."IT-MAC-NB165".options',
                },
              },
            },
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

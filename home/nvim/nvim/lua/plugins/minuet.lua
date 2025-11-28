return {}
  or {
    {
      "milanglacier/minuet-ai.nvim",
      opts = {
        provider_options = {
          codestral = {},
        },
      },
    },
    {
      "saghen/blink.cmp",
      optional = true,
      opts = {
        sources = {
          default = { "minuet" },
          providers = {
            minuet = {
              enabled = true,
              name = "minuet",
              module = "minuet.blink",
              async = true,
              -- Should match minuet.config.request_timeout * 1000,
              -- since minuet.config.request_timeout is in seconds
              timeout_ms = 3000,
              score_offset = 50, -- Gives minuet higher priority among suggestions
            },
          },
        },
      },
    },
    {
      "nvim-lualine/lualine.nvim",
      optional = true,
      event = "VeryLazy",
      opts = function(_, opts)
        local minet_lualine = require("minuet.lualine")

        table.insert(opts.sections.lualine_x, 2, {
          minet_lualine,
          icon = LazyVim.config.icons.kinds.Copilot,
          color = { fg = Snacks.util.color("Special") },
          -- minuet-lualine component options
          display_name = "provider",
        })
      end,
    },
  }

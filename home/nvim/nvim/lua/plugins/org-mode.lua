return {}
  or {
    {
      "nvim-orgmode/orgmode",
      event = "VeryLazy",
      dependencies = {
        {
          "danilshvalov/org-modern.nvim",
        },
      },
      config = function()
        local Menu = require("org-modern.menu")
        require("orgmode").setup({
          org_agenda_files = "~/org/*",
          org_default_notes_file = "~/org/refile.org",
          org_log_done = "note",
          org_startup_indented = true,
          org_indent_mode_turns_on_hiding_stars = false,
          org_agenda_start_on_weekday = false, -- week starts from today
          mappings = {
            org = {
              org_change_date = "cd",
              org_timestamp_up = "<C-a>",
              org_timestamp_down = "<C-x>",
              org_priority = "cp",
              org_todo = "cs", -- [c]hange [s]tatus
              org_toggle_checkbox = "ct",
            },
          },
          ui = {
            menu = {
              handler = function(data)
                Menu:new():open(data)
              end,
            },
          },
        })
      end,
    },
    {
      "chipsenkbeil/org-roam.nvim",
      -- tag = "0.1.1",
      version = "*",
      dependencies = {
        {
          "nvim-orgmode/orgmode",
          -- tag = "0.3.7",
        },
      },
      opts = {
        directory = "~/org_roam_files",
        -- optional
        -- org_files = {
        --   "~/another_org_dir",
        --   "~/some/folder/*.org",
        --   "~/a/single/org_file.org",
        -- },
        bindings = {
          prefix = "<localleader>n",
        },
      },
    },
    {
      "saghen/blink.cmp",
      opts = {
        sources = {
          per_filetype = {
            org = { "orgmode" },
          },
          providers = {
            orgmode = {
              name = "Orgmode",
              module = "orgmode.org.autocompletion.blink",
              fallbacks = { "buffer" },
            },
          },
        },
      },
    },
    {
      "akinsho/org-bullets.nvim",
      dependencies = {
        "nvim-orgmode/orgmode",
      },
      opts = {},
    },
    {
      "folke/which-key.nvim",
      opts = {
        spec = {
          {
            { "<leader>o", group = "org", icon = "" },
            { "<leader>oi", group = "org insert" },
            { "<leader>ol", group = "org link" },
            { "<leader>ox", group = "org clocking" },

            { "<localleader>n", group = "org-roam", icon = "" },
          },
        },
      },
    },
  }

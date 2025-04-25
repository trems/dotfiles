return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        trigger = {
          show_on_insert_on_trigger_character = true,
          show_on_keyword = true,
          show_on_trigger_character = true,
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          max_height = 15,
          draw = {
            align_to = "label",
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
        ghost_text = {
          enabled = false,
        },
        documentation = {
          treesitter_highlighting = false,
        },
      },
      signature = {
        enabled = false,
      },
      keymap = {
        preset = "enter",
        -- ["<Esc>"] = { "cancel" },
      },
      sources = {
        providers = {
          snippets = {
            should_show_items = function(ctx)
              return ctx.trigger.initial_kind ~= "trigger_character"
            end,
          },
          -- codeium = {
          --   max_items = 3,
          -- },
        },
      },
    },
  },
}

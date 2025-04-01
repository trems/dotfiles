return {
  {
    "Wansmer/langmapper.nvim",
    lazy = false,
    enabled = false,
    priority = 1, -- High priority is needed if you will use `autoremap()`
    opts = {},
  },
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local lmu = require("langmapper.utils")
      local wk_state = require("which-key.state")
      local check_orig = wk_state.check

      wk_state.check = function(state, key) ---@diagnostic disable-line: duplicate-set-field
        if key ~= nil then
          key = lmu.translate_keycode(key, "default", "ru")
        end
        if state.node.key ~= nil then
          state.node.key = lmu.translate_keycode(state.node.key, "default", "ru")
        end
        -- if state.node.keys ~= nil then
        --   vim.notify("node keys: " .. state.node.key)
        --   state.node.keys = lmu.translate_keycode(state.node.keys, "default", "ru")
        -- end

        return check_orig(state, key)
      end

      -- don't show mappings translated by langmapper.nvim. Show entry if func returns true
      opts.filter = function(mapping)
        return mapping.lhs
          and mapping.lhs == lmu.translate_keycode(mapping.lhs, "default", "ru")
          and mapping.desc
          and mapping.desc:find("LM") == nil
      end
    end,
  },
}

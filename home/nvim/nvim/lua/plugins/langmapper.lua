return {
  {
    "Wansmer/langmapper.nvim",
    lazy = false,
    enabled = true,
    priority = 1, -- High priority is needed if you will use `autoremap()`
    opts = {},
  },
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local translate_key = require("langmapper.utils").translate_keycode
      opts.filter = function(mapping)
        return mapping.lhs
          and mapping.lhs == translate_key(mapping.lhs, "default", "ru")
          and mapping.desc
          and mapping.desc:find("LM") == nil
      end
    end,
  },
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, _)
      local translate_key = require("langmapper.utils").translate_keycode
      local normkey_orig = Snacks.util.normkey
      Snacks.util.normkey = function(key)
        if key then
          key = translate_key(key, "default", "ru")
        end
        return normkey_orig(key)
      end
    end,
  },
}

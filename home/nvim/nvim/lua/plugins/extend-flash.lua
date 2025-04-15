return {
  -- {
  --   "folke/flash.nvim",
  --   opts = {
  --     labels = function()
  --       return "йцукенг"
  --     end,
  --   },
  "folke/flash.nvim",
  event = "VeryLazy",
  config = function()
    local flash = require("flash")
    local langmapper = require("langmapper")

    for _, mode in pairs({ "n", "x", "o" }) do
      langmapper.original_set_keymap(mode, "s", "", {
        nowait = true,
        desc = "Flash",
        callback = function()
          flash.jump()
        end,
      })
      langmapper.original_set_keymap(mode, "ы", "", {
        nowait = true,
        desc = "Flash",
        callback = function()
          flash.jump({
            labels = "олджавыфгнрткепимйцуячсшщзьбюАВЫФОЛДЖЙЦУКЕНГШЩЗ",
          })
        end,
      })
    end

    ---@type Flash.Config
    local opts = { modes = { char = { enabled = false } } }

    flash.setup(opts)
  end, -- },
}

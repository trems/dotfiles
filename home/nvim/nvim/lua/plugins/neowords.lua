local function get_hops()
  local neowords = require("neowords")
  local p = neowords.pattern_presets

  local h = neowords.get_word_hops(p.snake_case, p.camel_case, p.upper_case, p.number, p.hex_color, "\\v\\.+", "\\v,+")

  return h
end

local hops = {}

return {
  -- "backdround/neowords.nvim",
  -- config = function()
  --   hops = get_hops()
  -- end,
  keys = {
    {
      "w",
      function()
        hops.forward_start()
      end,
      mode = { "n", "o", "x" },
      desc = "Move to start of next of word",
    },
    {
      "e",
      function()
        hops.forward_end()
      end,
      mode = { "n", "o", "x" },
      desc = "Move to end of word",
    },
    {
      "b",
      function()
        hops.backward_start()
      end,
      mode = { "n", "o", "x" },
      desc = "Move to start of previous word",
    },
    {
      "ge",
      function()
        hops.backward_end()
      end,
      mode = { "n", "o", "x" },
      desc = "Move to start of previous word",
    },
  },
}

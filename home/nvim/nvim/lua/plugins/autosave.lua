return {
  "Pocco81/auto-save.nvim",
  lazy = false,
  opts = {
    debounce_delay = 500,
    execution_message = {
      message = function()
        return ""
      end,
    },
  },
  keys = {
    { "<Leader>uv", "<cmd>ASToggle<CR>", desc = "Toggle AutoSave" },
  },
}

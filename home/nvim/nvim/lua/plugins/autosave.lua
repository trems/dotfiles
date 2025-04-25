return {
  "okuuva/auto-save.nvim",
  version = "*",
  cmd = "ASToggle",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    debounce_delay = 2000,
  },
  keys = {
    { "<Leader>uv", "<cmd>ASToggle<CR>", desc = "Toggle Auto-Save" },
  },
}

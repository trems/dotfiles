-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- vim.keymap.set("i", "jj", "<esc>", { silent = true, noremap = true })
vim.api.nvim_set_keymap("n", "<localleader>j", "", {
  -- noremap = true,
  desc = "test localleader",
  callback = function()
    vim.notify("notify!")
  end,
})

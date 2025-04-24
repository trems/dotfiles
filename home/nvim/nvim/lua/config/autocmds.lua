-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.api.nvim_create_augroup("conceal_settings", { clear = true })

-- Set conceallevel for specific file types
vim.api.nvim_create_autocmd("FileType", {
  group = "conceal_settings",
  pattern = { "*json*", "http" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

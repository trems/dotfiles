-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.o.wrap = true
vim.o.virtualedit = "block,onemore"
vim.o.spelllang = "en,ru"
vim.o.spelloptions = "camel"
vim.o.langmap =
  "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ, фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz"

if vim.g.neovide then
  vim.g.neovide_text_gamma = 0.1
  vim.g.neovide_cursor_animation_length = 0
end

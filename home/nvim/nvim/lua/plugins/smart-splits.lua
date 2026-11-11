return {
  {
    "mrjones2014/smart-splits.nvim",
    -- enabled = false,
    lazy = false,
    opts = {
      -- в Herdr нет мультиплексора для smart-splits: на краю отдаём переход Herdr
      at_edge = vim.env.HC_TERMINAL_ID and function(ctx)
        vim.system({ "herdr-app", "do", "pane.go", "--direction", ctx.direction })
      end or nil,
    },
    -- stylua: ignore
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, mode = { "n" }, desc = "Move left", },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, mode = { "n" }, desc = "Move down", },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, mode = { "n" }, desc = "Move up", },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, mode = { "n" }, desc = "Move right", },
      { "<A-h>", function() require("smart-splits").resize_left() end, mode = { "n" }, desc = "Resize left", },
      { "<A-j>", function() require("smart-splits").resize_down() end, mode = { "n" }, desc = "Resize left", },
      { "<A-k>", function() require("smart-splits").resize_up() end, mode = { "n" }, desc = "Resize up", },
      { "<A-l>", function() require("smart-splits").resize_right() end, mode = { "n" }, desc = "Resize right", },
    },
  },
}

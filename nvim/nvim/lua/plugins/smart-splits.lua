return {
  {
    "mrjones2014/smart-splits.nvim",
    -- enabled = false,
    lazy = false,
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

return {
  "akinsho/git-conflict.nvim",
  -- lazy = false,
  tag = "v2.1.0",
  -- config = true,
  opts = {
    default_mappings = {
      ours = "<leader>ho",
      theirs = "<leader>ht",
      none = "<leader>h0",
      both = "<leader>hb",
      next = "]x",
      prev = "[x",
    },
  },
  keys = {
    {
      "<leader>gx",
      "<cmd>GitConflictListQf<cr>",
      desc = "List Conflicts",
    },
    {
      "<leader>gr",
      "<cmd>GitConflictRefresh<cr>",
      desc = "Refresh Conflicts",
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n" },
          { "<leader>h", group = "git-conflict" },
        },
      },
    },
  },
}

return {
  "mini-nvim/mini.files",
  enabled = false,
  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (directory of current file)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
    { "<leader>fm", false },
    { "<leader>fM", false },
  },
  opts = {
    options = {
      use_as_default_explorer = true,
    },
  },
}

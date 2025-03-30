return {
  {
    "maxandron/goplements.nvim",
    ft = { "go" },
    opts = {
      display_package = true,
    },
    keys = {
      {
        "<leader>ui",
        mode = { "n" },
        function()
          require("goplements").toggle()
        end,
        desc = "Toggle Go Implements Hints",
      },
    },
  },
}

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>sG",
        function()
          Snacks.picker.grep({ dirs = { vim.fn.expand("%:p:h") } })
        end,
        desc = "Grep (current buf dir)",
      },
    },
  },
}

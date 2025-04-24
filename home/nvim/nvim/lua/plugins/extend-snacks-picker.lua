return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        previewers = {
          diff = { builtin = false, cmd = { "delta" } },
          git = { builtin = false },
        },
        sources = {
          files = {
            hidden = true,
            ignored = true,
          },
          grep = {
            need_search = false,
          },
        },
      },
    },
    -- stylua: ignore
    keys = {
        -- Top Pickers & Explorer
        { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
        { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
        { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
        { "<leader>sG", function() Snacks.picker.grep({ dirs = { vim.fn.expand("%:p:h") }}) end, desc = "Grep (current buf dir)" },
    },
  },
}

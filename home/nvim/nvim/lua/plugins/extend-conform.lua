return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      ["sql"] = { "sqlfluff" },
    },
    formatters = {
      sqlfluff = {
        args = { "format", "-" },
      },
    },
  },
}

return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      go = { "golangcilint" },
      proto = { "buf_lint" },
    },
  },
}

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ["proto"] = { "buf_lint" },
        ["sql"] = { "sqlfluff" },
        -- ["go"] = { "golangcilint" },
      },
      linters = {
        sqlfluff = {
          args = { "lint", "--format=json", "-" },
          stdin = true,
        },
        golangcilint = {
          condition = function(ctx)
            return false
            -- exclude files from 'vendor' folder
            local root_dir = vim.fs.root(ctx.filename, { "go.mod", "go.work" })

            for parent_dir in vim.fs.parents(ctx.filename) do
              local dir_name = vim.fs.basename(parent_dir)
              if dir_name == "vendor" and vim.fs.dirname(parent_dir) == root_dir then
                return false
              end
            end

            return true
          end,
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    event = "VeryLazy",
    opts = function(_, opts)
      local lint_progress = function()
        local linters = require("lint").get_running()
        if #linters == 0 then
          return "󰦕"
        end
        return "󱉶 " .. table.concat(linters, ", ")
      end
      table.insert(opts.sections.lualine_x, 2, lint_progress)
    end,
  },
}

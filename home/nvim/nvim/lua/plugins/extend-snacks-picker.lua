local explorer_copy_file_path = function(_, item)
  if not item then
    return
  end

  local vals = {
    ["BASENAME"] = vim.fn.fnamemodify(item.file, ":t:r"),
    ["EXTENSION"] = vim.fn.fnamemodify(item.file, ":t:e"),
    ["FILENAME"] = vim.fn.fnamemodify(item.file, ":t"),
    ["PATH"] = item.file,
    ["PATH (CWD)"] = vim.fn.fnamemodify(item.file, ":."),
    ["PATH (HOME)"] = vim.fn.fnamemodify(item.file, ":~"),
    ["URI"] = vim.uri_from_fname(item.file),
  }

  local options = vim.tbl_filter(function(val)
    return vals[val] ~= ""
  end, vim.tbl_keys(vals))

  if vim.tbl_isempty(options) then
    vim.notify("No values to copy", vim.log.levels.WARN)
    return
  end

  table.sort(options)
  vim.ui.select(options, {
    prompt = "Choose to copy to clipboard:",
    format_item = function(list_item)
      return ("%s: %s"):format(list_item, vals[list_item])
    end,
  }, function(choice)
    local result = vals[choice]
    if result then
      vim.fn.setreg("+", result)
      Snacks.notify.info("Yanked `" .. result .. "`")
    end
  end)
end

local explorer_find_in_directory = function(_, item)
  if not item then
    return
  end
  local dir = vim.fn.fnamemodify(item.file, ":p:h")
  Snacks.picker.grep({
    cwd = dir,
    -- cmd = "rg",
    -- args = {
    --   "-g",
    --   "!.git",
    --   "-g",
    --   "!node_modules",
    --   "-g",
    --   "!dist",
    --   "-g",
    --   "!build",
    --   "-g",
    --   "!coverage",
    --   "-g",
    --   "!.DS_Store",
    --   "-g",
    --   "!.docusaurus",
    --   "-g",
    --   "!.dart_tool",
    -- },
    show_empty = true,
    hidden = true,
    ignored = true,
    follow = false,
    supports_live = true,
  })
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        previewers = {
          diff = { builtin = false, cmd = { "delta" } },
          git = { builtin = false },
        },
        sources = {
          files = {
            hidden = true,
          },
          explorer = {
            auto_close = true,
            hidden = true,
            ignored = true,
            exclude = { ".git", "vendor" },
            layout = {
              preset = "sidebar",
              preview = true,
            },
            actions = {
              copy_file_path = {
                action = explorer_copy_file_path,
              },
              find_in_directory = { action = explorer_find_in_directory },
              diff = { action = explorer_diff },
            },
            win = {
              list = {
                keys = {
                  ["y"] = "copy_file_path",
                  ["s"] = "find_in_directory",
                  ["D"] = "diff",
                },
              },
            },
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
        -- { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
        -- { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notification History" },
        -- { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
        -- find
        -- { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
        -- { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
        -- { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
        -- { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
        -- { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
        -- { "<leader>fr", function() Snacks.picker.recent({filter = {cwd = true}}) end, desc = "Recent" },
        -- git
        -- { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
        -- { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
        -- { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Git Log Line" },
        -- { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
        -- { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
        -- { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },
        -- { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git Log File" },
        -- Grep
        -- { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
        -- { "<leader>sg", LazyVim.pick("live_grep", {}), desc = "Grep (Root Dir)" },
        { "<leader>sG", function() Snacks.picker.grep({ dirs = { vim.fn.expand("%:p:h") }}) end, desc = "Grep (current buf dir)" },
        -- { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
        -- search
        -- { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
        -- { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
        -- { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
        -- { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
        -- { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
        -- { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
        -- { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
        -- { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
        -- { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
        -- { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
        -- { "<leader>si", function() Snacks.picker.icons() end, desc = "Icons" },
        -- { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
        -- { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
        -- { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
        -- { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
        -- { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
        -- { "<leader>sp", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
        -- { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
        -- { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
        -- { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },
        -- { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
        -- LSP
        -- { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
        -- { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
        -- { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
        -- { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
        -- { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
        -- { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
        -- { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
    },
  },
}

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
    show_empty = true,
    hidden = true,
    ignored = true,
    follow = false,
    supports_live = true,
  })
end

local explorer_diff = function(picker)
  picker:close()
  local sel = picker:selected()
  if #sel > 0 and sel then
    Snacks.notify.info(sel[1].file)
    vim.cmd("tabnew " .. sel[1].file)
    vim.cmd("vert diffs " .. sel[2].file)
    Snacks.notify.info("Diffing " .. sel[1].file .. " against " .. sel[2].file)
    return
  end

  Snacks.notify.info("Select two entries for the diff")
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
              preview = "main",
              auto_hide = { "input" },
            },
            actions = {
              copy_file_path = { action = explorer_copy_file_path },
              find_in_directory = { action = explorer_find_in_directory },
              diff = { action = explorer_diff },
            },
            win = {
              list = {
                keys = {
                  ["y"] = "copy_file_path",
                  ["f"] = "find_in_directory",
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
        { "<leader>sG", function() Snacks.picker.grep({ dirs = { vim.fn.expand("%:p:h") }}) end, desc = "Grep (current buf dir)" },
    },
  },
}

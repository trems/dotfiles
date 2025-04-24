local function explorer_copy_file_path(_, item)
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

local function explorer_find_in_directory(_, item)
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

local function explorer_diff(picker)
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

---@param picker  snacks.Picker
---@param item?   snacks.picker.Item
---@param action snacks.picker.Action
local function explorer_recursive_toggle(picker, item, action)
  local Actions = require("snacks.explorer.actions")
  local Tree = require("snacks.explorer.tree")

  local get_children = function(node)
    local children = {}
    for _, child in pairs(node.children) do
      table.insert(children, child)
    end
    return children
  end

  local refresh = function()
    Actions.update(picker, { refresh = true })
  end

  ---@param node snacks.picker.explorer.Node
  local function toggle_recursive(node)
    Tree:toggle(node.path)
    refresh()
    vim.schedule(function()
      local children = get_children(node)
      if #children ~= 1 then
        return
      end
      local child = children[1]
      if not child.dir then
        return
      end
      toggle_recursive(child)
    end)
  end

  local node = Tree:node(item.file)
  if not node then
    return
  end

  if node.dir then
    toggle_recursive(node)
  else
    picker:action("confirm")
  end
end

---@param opts? snacks.picker.explorer.Config
local function toggle_explorer(opts)
  local explorer_pickers = Snacks.picker.get({ source = "explorer" })
  for _, v in pairs(explorer_pickers) do
    if v:is_focused() then
      v:close()
    else
      v:focus()
    end
  end
  if #explorer_pickers == 0 then
    Snacks.picker.explorer(opts or {})
  end
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        sources = {
          explorer = {
            auto_close = false,
            hidden = true,
            ignored = true,
            exclude = { ".git" },
            ---@type snacks.picker.layout.Config
            layout = {
              preview = true,
              cycle = true,
              layout = {
                backdrop = false,
                height = 0,
                position = "left",
                border = "none",
                box = "horizontal",
                width = 40,
                {
                  box = "vertical",
                  width = 40,
                  min_width = 40,
                  {
                    win = "input",
                    height = 1,
                    border = "rounded",
                    title = "{title} {live} {flags}",
                    title_pos = "center",
                  },
                  { win = "list", border = "none" },
                },
                {
                  win = "preview",
                  title = "{preview}",
                  position = "float",
                  height = 100,
                  width = 100,
                  min_width = 70,
                  border = "none",
                },
              },
            },
            -- layout = {
            --   preview = true,
            --   cycle = true,
            --   layout = {
            --     box = "horizontal",
            --     position = "float",
            --     height = 0.95,
            --     width = 0,
            --     border = "rounded",
            --     {
            --       box = "vertical",
            --       width = 40,
            --       min_width = 40,
            --       { win = "input", height = 1, title = "{title} {live} {flags}", border = "single" },
            --       { win = "list" },
            --     },
            --     { win = "preview", width = 0, border = "left" },
            --   },
            -- },
            actions = {
              ---@alias snacks.picker.Action.fn fun(self: snacks.Picker, item?:snacks.picker.Item, action?:snacks.picker.Action):(boolean|string?)
              ---@alias snacks.picker.Action.spec.one string|snacks.picker.Action|snacks.picker.Action.fn|{action?:snacks.picker.Action.spec.one}
              ---@alias snacks.picker.Action.spec snacks.picker.Action.spec.one|snacks.picker.Action.spec.one[]
              confirm_and_close = function(picker, item, _)
                explorer_recursive_toggle(picker, item, _)
                picker:close()
              end,
              confirm_nofocus = function(picker, item, _)
                explorer_recursive_toggle(picker, item, _)
                picker:focus()
              end,
              copy_file_path = { action = explorer_copy_file_path },
              find_in_directory = { action = explorer_find_in_directory },
              diff = { action = explorer_diff },
            },
            main = {
              float = true,
            },
            win = {
              list = {
                keys = {
                  ["|"] = false,
                  ["<CR>"] = "confirm_and_close",
                  ["l"] = "confirm_nofocus",
                  ["Y"] = "copy_file_path",
                  ["f"] = "find_in_directory",
                  ["D"] = "diff", -- select 2 files with TAB or Shift-TAB and diff them
                },
              },
              preview = {
                width = 0.9,
              },
            },
          },
        },
      },
    },
    keys = {
      { "<leader>fe", false },
      { "<leader>fE", false },
      {
        "<leader>e",
        function()
          toggle_explorer({ cwd = LazyVim.root() })
        end,
        desc = "Explorer (root dir)",
      },
      {
        "<leader>E",
        function()
          toggle_explorer()
        end,
        desc = "Explorer (cwd)",
      },
    },
  },
}

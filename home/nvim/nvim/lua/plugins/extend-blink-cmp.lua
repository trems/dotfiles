local source_icons = {
  minuet = "󱗻",
  orgmode = "",
  otter = "󰼁",
  nvim_lsp = "",
  lsp = "",
  buffer = "",
  luasnip = "",
  snippets = "",
  path = "",
  git = "",
  tags = "",
  cmdline = "󰘳",
  latex_symbols = "",
  cmp_nvim_r = "󰟔",
  codeium = "󰩂",
  -- FALLBACK
  fallback = "󰜚",
}

local function serializeTable(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0

  local tmp = string.rep(" ", depth)

  if name then
    tmp = tmp .. name .. " = "
  end

  if type(val) == "table" then
    tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

    for k, v in pairs(val) do
      tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
    end

    tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
    tmp = tmp .. (val and "true" or "false")
  else
    tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
  end

  return tmp
end

return {
  {
    "saghen/blink.cmp",
    dependencies = {
      { "milanglacier/minuet-ai.nvim", optional = true },
    },
    opts = {
      appearance = {
        nerd_font_variant = "normal",

        kind_icons = {
          claude = "󰋦",
          openai = "󱢆",
          codestral = "󱎥",
          gemini = "",
          Openrouter = "󱂇",
          Ollama = "󰳆",
          ["Llama.cpp"] = "󰳆",
          Deepseek = "",
        },
      },
      completion = {
        trigger = {
          show_on_insert_on_trigger_character = true,
          show_on_keyword = true,
          show_on_trigger_character = true,
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          max_height = 15,
          draw = {
            align_to = "label",
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
        },
        ghost_text = {
          enabled = false,
        },
        documentation = {
          auto_show = true,
          treesitter_highlighting = true,
          draw = function(opts)
            -- local s_opts = serializeTable(opts)
            -- print(s_opts)
            opts.default_implementation()
          end,
        },
      },
      signature = {
        enabled = false,
      },
      keymap = {
        preset = "enter",
        -- ["<Esc>"] = { "cancel" },
      },
      sources = {
        providers = {
          snippets = {
            should_show_items = function(ctx)
              return ctx.trigger.initial_kind ~= "trigger_character"
            end,
          },
        },
      },
    },
  },
}

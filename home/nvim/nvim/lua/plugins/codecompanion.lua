local default_model = "qwen/qwen3-32b:free"
local openrouter_models = {}
local current_model = default_model

local function select_model()
  vim.ui.select(openrouter_models, {
    prompt = "Select  Model:",
  }, function(choice)
    if choice then
      current_model = choice
      vim.notify("Selected model: " .. current_model)
    end
  end)
end

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = function(_, opts)
      local current_adapter = "ucb_ollama"
      opts.strategies = {
        chat = {
          adapter = current_adapter,
        },
        inline = {
          adapter = current_adapter,
        },
        cmd = {
          adapter = current_adapter,
        },
      }

      local default_system_prompt = require("codecompanion.config").opts.system_prompt
      opts.opts = {
        -- language = "Russian",
        system_prompt = function(opts)
          return default_system_prompt(opts) .. "\n/no_think"
        end,
      }
      opts.adapters = {
        opts = {
          show_defaults = false,
        },
        lm_studio = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "lm_studio_qwen3_8b",
            formatted_name = "LM Studio (Qwen3 8b)",
            env = {
              url = "http://127.0.0.1:1234", -- optional: default value is ollama url http://127.0.0.1:11434
              api_key = "no-key", -- optional: if your endpoint is authenticated
              chat_url = "/v1/chat/completions", -- optional: default value, override if different
              models_endpoint = "/v1/models", -- optional: attaches to the end of the URL to form the endpoint to retrieve models
            },
            schema = {
              model = {
                default = "qwen3-8b-mlx",
              },
            },
          })
        end,
        ucb_ollama = function()
          return require("codecompanion.adapters").extend("ollama", {
            env = {
              url = "UCB_OLLAMA_URL",
              api_key = "no_key",
            },
            headers = {
              ["Content-Type"] = "application/json",
              ["Authorization"] = "Bearer ${api_key}",
            },
            parameters = {
              sync = true,
            },
          })
        end,
        openrouter = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            env = {
              url = "https://openrouter.ai/api",
              api_key = vim.env.OPENROUTER_API_KEY,
              chat_url = "/v1/chat/completions",
            },
            schema = {
              model = {
                default = current_model,
              },
            },
          })
        end,
      }
    end,
    keys = {
      { "<leader>a", "", desc = "+companion", mode = { "n", "v" } },
      {
        "<leader>am",
        function()
          select_model()
        end,
        desc = "CC Select model",
        mode = { "n", "v" },
      },
      { "<leader>ac", "<cmd>CodeCompanionChat<CR>", desc = "CC Chat", mode = { "n", "v" } },
      { "<leader>aa", "<cmd>CodeCompanionActions<CR>", desc = "CC Actions", mode = { "n", "v" } },
    },
  },
}

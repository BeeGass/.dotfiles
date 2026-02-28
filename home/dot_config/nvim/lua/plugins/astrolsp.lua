---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    formatting = {
      format_on_save = {
        enabled = true,
      },
    },
    servers = {
      "lua_ls",
      "pyright",
      "ruff",
      "ts_ls",
      "bashls",
      "jsonls",
      "yamlls",
      "taplo",
      "rust_analyzer",
    },
    config = {
      lua_ls = {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      },
    },
  },
}

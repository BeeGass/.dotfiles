---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format", "ruff_fix" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        lua = { "stylua" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
      },
    },
  },
  -- Disable textobjects until it supports nvim-treesitter 1.x (configs module removed)
  { "nvim-treesitter/nvim-treesitter-textobjects", enabled = false },
}

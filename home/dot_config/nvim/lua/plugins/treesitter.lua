---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "bash",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "regex",
      "rust",
      "toml",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    },
  },
}

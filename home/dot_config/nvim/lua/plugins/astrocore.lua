---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = {
      update_in_insert = false,
    },
    options = {
      opt = {
        number = true,
        relativenumber = true,
        signcolumn = "yes",
        wrap = false,
        scrolloff = 8,
        sidescrolloff = 8,
        clipboard = "unnamedplus",
        tabstop = 2,
        shiftwidth = 2,
        expandtab = true,
        smartindent = true,
        termguicolors = true,
        undofile = true,
        updatetime = 250,
        timeoutlen = 300,
      },
    },
    -- Colemak-DH navigation remapping
    -- r=left(h), s=down(j), f=up(k), t=right(l)
    -- Displaced originals: l=replace(r), j=substitute(s), k=find(f), n=till(t)
    mappings = {
      n = {
        -- Colemak-DH movement
        ["r"] = { "h", desc = "Left" },
        ["s"] = { "j", desc = "Down" },
        ["f"] = { "k", desc = "Up" },
        ["t"] = { "l", desc = "Right" },
        -- Displaced keys
        ["l"] = { "r", desc = "Replace" },
        ["j"] = { "s", desc = "Substitute" },
        ["k"] = { "f", desc = "Find char" },
        ["K"] = { "F", desc = "Find char backward" },
        ["n"] = { "t", desc = "Till char" },
        ["N"] = { "T", desc = "Till char backward" },
        -- Window navigation (Colemak-DH)
        ["<C-r>"] = { "<C-w>h", desc = "Move to left window" },
        ["<C-s>"] = { "<C-w>j", desc = "Move to lower window" },
        ["<C-f>"] = { "<C-w>k", desc = "Move to upper window" },
        ["<C-t>"] = { "<C-w>l", desc = "Move to right window" },
        -- Redo (displaced by C-r window nav)
        ["U"] = { "<C-r>", desc = "Redo" },
        -- Buffer navigation
        ["<S-t>"] = {
          function()
            require("astrocore.buffer").nav(vim.v.count1)
          end,
          desc = "Next buffer",
        },
        ["<S-r>"] = {
          function()
            require("astrocore.buffer").nav(-vim.v.count1)
          end,
          desc = "Previous buffer",
        },
        -- Centered scrolling
        ["<C-d>"] = { "<C-d>zz", desc = "Scroll down (centered)" },
        ["<C-u>"] = { "<C-u>zz", desc = "Scroll up (centered)" },
      },
      v = {
        -- Colemak-DH movement in visual mode
        ["r"] = { "h", desc = "Left" },
        ["s"] = { "j", desc = "Down" },
        ["f"] = { "k", desc = "Up" },
        ["t"] = { "l", desc = "Right" },
        -- Displaced keys
        ["l"] = { "r", desc = "Replace" },
        ["j"] = { "s", desc = "Substitute" },
        ["k"] = { "f", desc = "Find char" },
        ["K"] = { "F", desc = "Find char backward" },
        ["n"] = { "t", desc = "Till char" },
        ["N"] = { "T", desc = "Till char backward" },
        -- Move selected lines
        ["<A-s>"] = { ":move '>+1<CR>gv=gv", desc = "Move selection down" },
        ["<A-f>"] = { ":move '<-2<CR>gv=gv", desc = "Move selection up" },
      },
      o = {
        -- Colemak-DH movement in operator-pending mode
        ["r"] = { "h", desc = "Left" },
        ["s"] = { "j", desc = "Down" },
        ["f"] = { "k", desc = "Up" },
        ["t"] = { "l", desc = "Right" },
        -- Displaced keys
        ["k"] = { "f", desc = "Find char" },
        ["K"] = { "F", desc = "Find char backward" },
        ["n"] = { "t", desc = "Till char" },
        ["N"] = { "T", desc = "Till char backward" },
      },
    },
  },
}

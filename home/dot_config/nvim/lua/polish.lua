-- post-setup tweaks
return function()
  -- highlight yanked text briefly
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
    callback = function()
      vim.highlight.on_yank({ higroup = "Visual", timeout = 200 })
    end,
  })
end

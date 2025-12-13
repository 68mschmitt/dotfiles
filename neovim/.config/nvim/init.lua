require("mike.options")
require('mike.lazy')
require("mike.autocmd")
require("mike.statusline")
vim.cmd([[colorscheme carbonfox]])
require("mike.keymaps")

-- Custom Autocenter for Note
require("mike.autocenter").setup({
  enabled = false,
  updatetime = 250,
  cooldown_ms = 400,
  align = "zz",       -- or "zt"
  keymap = "<leader>uz",
})


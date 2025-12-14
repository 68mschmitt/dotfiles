require("mike.options")
require('mike.lazy')
require("mike.autocmd")
require("mike.statusline")
vim.cmd([[colorscheme carbonfox]])
require("mike.keymaps")

-- Custom Autocenter for Note
require("mike.autocenter").setup({
  enabled = false,  -- start disabled
  align = "zz",     -- or "zt"
  keymap = "<leader>uz",
})

require("mike.surround_wrap").setup()

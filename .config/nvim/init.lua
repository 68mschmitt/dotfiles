-- Hybrid relative line number
vim.wo.number = true
vim.wo.relativenumber = true

-- Lazy vim for plugins
require("config.lazy")

require("config.nvim-tree")

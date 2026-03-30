vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

-- Set in lazy.lua
-- vim.g.mapleader = " "

-- preview substitutions live
vim.opt.inccommand = "split"

-- decrease update time
vim.opt.updatetime = 200
vim.opt.timeout = true
vim.opt.timeoutlen = 300

-- split windows
vim.opt.splitright = true
vim.opt.splitbelow = true

-- cursor line visibility
vim.opt.cursorline = true

-- show whitespace characters
vim.opt.list = true
vim.opt.listchars = { tab = "\u{bb} ", trail = "\u{b7}", nbsp = "\u{2423}" }

-- ask instead of erroring on unsaved changes
vim.opt.confirm = true

-- make jumplist behave like browser back/forward
vim.opt.jumpoptions = "stack"

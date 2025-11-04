-- Copy the current buffer file name to the default register
vim.keymap.set("n", "<leader>nf", "<cmd>let @\" = expand(\"%:t\")\"<cr>", { noremap = true, silent = true })

-- Close the quickfix window
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr><cmd>cclose<cr>", { noremap = true, silent = true })

-- Clear word highlighting
vim.keymap.set("n", "<leader>nh", "<cmd>noh<cr>", { noremap = true, silent = true })

-- QOL
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { noremap = true, silent = true })

-- Center the screen when searching
vim.keymap.set("n", "n", "nzz", { noremap = true, silent = true })
vim.keymap.set("n", "N", "Nzz", { noremap = true, silent = true })

-- Navigate splits
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

-- Resize splits
vim.keymap.set("n", "<C-A-l>", ":vert res +3 <CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-A-h>", ":vert res -3 <CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-A-j>", ":res +3 <CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-A-k>", ":res -3 <CR>", { noremap = true, silent = true })

-- Move to the next or previous buffer with Tab and Shift-Tab
vim.keymap.set("n", "<Tab>", ":bnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-Tab>", ":bprev<CR>", { noremap = true, silent = true })

-- Move a highlighted line up or down 1 line
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })

-- Keep cursor in place when removing the line break at the end of a line
vim.keymap.set("n", "J", "mzJ`z", { noremap = true, silent = true })

-- While in highlight mode, delete the highlighted text and paste the yanked text
vim.keymap.set("x", "<leader>p", "\"_dP", { noremap = true, silent = true })

-- Delete into the void
vim.keymap.set("n", "<leader>d", "\"_dP", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>d", "\"_dP", { noremap = true, silent = true })

-- Yank into the system clipboard, awesome
vim.keymap.set("n", "<leader>y", "\"+y", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>y", "\"+y", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>Y", "\"+Y", { noremap = true, silent = true })

-- Tab keymaps
vim.keymap.set("n", "<leader>tn", "<cmd>.tabnew<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>te", "<cmd>tabc<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>to", "<cmd>tabo<cr>", { noremap = true, silent = true })

-- Execute lua inline
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>x", ":.lua<cr>", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>x", ":lua<cr>", { noremap = true, silent = true })

-- Quick fix navigation
vim.keymap.set("n", "<A-n>", "<cmd>cnext<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<A-p>", "<cmd>cprev<cr>", { noremap = true, silent = true })

-- Close a buffer
vim.keymap.set("n", "<leader>cb", "<cmd>bdel!<cr>", { noremap = true, silent = true })

-- Manual lint trigger
vim.keymap.set("n", "<leader>ll", function()
    require("lint").try_lint()
end, { noremap = true, silent = true, desc = "Lint current buffer" })

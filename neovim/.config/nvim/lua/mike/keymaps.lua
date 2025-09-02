-- Experimenting with friction
vim.api.nvim_set_keymap("i", "<C-n><C-n>", "<Esc>o", { noremap = true, silent = true })

-- Clear search highlights and close the quickfix window
vim.api.nvim_set_keymap("n", "<Esc>", "<cmd>noh<cr><cmd>cclose<cr>", { noremap = true, silent = true })

-- QOL
vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>w<cr>", { noremap = true, silent = true })

-- Center the screen when searching
vim.api.nvim_set_keymap("n", "n", "nzz", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "N", "Nzz", { noremap = true, silent = true })

-- Navigate splits
vim.api.nvim_set_keymap("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

-- Resize splits
vim.api.nvim_set_keymap("n", "<C-A-l>", ":vert res +3 <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-A-h>", ":vert res -3 <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-A-j>", ":res +3 <CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-A-k>", ":res -3 <CR>", { noremap = true, silent = true })

-- Move to the next or previous buffer with Tab and Shift-Tab
vim.api.nvim_set_keymap("n", "<Tab>", ":bnext<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<S-Tab>", ":bprev<CR>", { noremap = true, silent = true })

-- Move a highlighted line up or down 1 line
vim.api.nvim_set_keymap("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })

-- Keep cursor in place when removing the line break at the end of a line
vim.api.nvim_set_keymap("n", "J", "mzJ`z", { noremap = true, silent = true })

-- While in highlight mode, delete the highlighted text and paste the yanked text
vim.api.nvim_set_keymap("x", "<leader>p", "\"_dP", { noremap = true, silent = true })

-- Delete into the void
vim.api.nvim_set_keymap("n", "<leader>d", "\"_dP", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>d", "\"_dP", { noremap = true, silent = true })

-- Yank into the system clipboard, awesome
vim.api.nvim_set_keymap("n", "<leader>y", "\"+y", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>y", "\"+y", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>Y", "\"+Y", { noremap = true, silent = true })

-- Tab keymaps
vim.api.nvim_set_keymap("n", "<leader>tn", "<cmd>.tabnew<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>te", "<cmd>tabc<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>to", "<cmd>tabo<cr>", { noremap = true, silent = true })

-- Execute lua inline
vim.api.nvim_set_keymap("n", "<leader><leader>x", "<cmd>source %<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>x", ":.lua<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>x", ":lua<cr>", { noremap = true, silent = true })

-- Quick fix navigation
vim.api.nvim_set_keymap("n", "<A-n>", "<cmd>cnext<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-p>", "<cmd>cprev<cr>", { noremap = true, silent = true })

-- Close a buffer
vim.api.nvim_set_keymap("n", "<leader>cb", "<cmd>bdel!<cr>", { noremap = true, silent = true })

-- Dap Keymaps
vim.api.nvim_set_keymap("n", "<F5>", "<cmd>lua require'dap'.continue()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F10>", "<cmd>lua require'dap'.step_over()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F11>", "<cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<F12>", "<cmd>lua require'dap'.step_out()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>b", "<cmd>lua require('dap').toggle_breakpoint()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>B", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: ', { noremap = true, silent = true }), { noremap = true, silent = true })<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>lp", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: ', { noremap = true, silent = true }), { noremap = true, silent = true })<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>dr", "<cmd>lua require'dap'.repl.open()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>dl", "<cmd>lua require'dap'.run_last()<CR>", { noremap = true, silent = true })

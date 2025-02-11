vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Move a highlighted line up or down 1 line
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Keep cursor in place when removing the line break at the end of a line
vim.keymap.set("n", "J", "mzJ`z")

-- Scroll up and down while staying centered in the page
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- /searching for words in the file centers the n/N result
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- While in highlight mode, delete the highlighted text and paste the yanked text
vim.keymap.set("x", "<leader>p", "\"_dP")

-- Delete into the void
vim.keymap.set("n", "<leader>d", "\"_dP")
vim.keymap.set("v", "<leader>d", "\"_dP")

-- Yank into the system clipboard, awesome
vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

-- Quick fix navigation
vim.keymap.set("n", "<C-k>", "<cmd>cnect<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

-- Tab keymaps
vim.keymap.set("n", "<leader>tn", "<cmd>.tabnew<cr><cmd>Ex<cr>")
vim.keymap.set("n", "<leader>te", "<cmd>tabc<cr>")
vim.keymap.set("n", "<leader>to", "<cmd>tabo<cr>")

-- Dap Keymaps
vim.keymap.set("n", "<F5>", "<cmd>lua require'dap'.continue()<CR>")
vim.keymap.set("n", "<F10>", "<cmd>lua require'dap'.step_over()<CR>")
vim.keymap.set("n", "<F9>", "<cmd>lua require'dap'.toggle_breakpoint()<CR>")

vim.keymap.set("n", "<F5>", "<cmd>lua require'dap'.continue()<CR>")
vim.keymap.set("n", "<F10>", "<cmd>lua require'dap'.step_over()<CR>")
vim.keymap.set("n", "<F11>", "<cmd>lua require'dap'.step_into()<CR>")
vim.keymap.set("n", "<F12>", "<cmd>lua require'dap'.step_out()<CR>")
vim.keymap.set("n", "<Leader>b", "<cmd>lua require'dap'.toggle_breakpoint()<CR>")
vim.keymap.set("n", "<Leader>B", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>")
vim.keymap.set("n", "<Leader>lp", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>")
vim.keymap.set("n", "<Leader>dr", "<cmd>lua require'dap'.repl.open()<CR>")
vim.keymap.set("n", "<Leader>dl", "<cmd>lua require'dap'.run_last()<CR>")

vim.keymap.set("n", "<leader>acd", function() require('cmp').setup.buffer { enabled = false } end)
vim.keymap.set("n", "<leader>ace", function() require('cmp').setup.buffer { enabled = true } end)

vim.keymap.set("n", "<leader>tp", "<cmd>lua ColorMyEditor()<CR>")

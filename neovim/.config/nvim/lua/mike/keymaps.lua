-- Copy the current buffer file name to the system clipboard
vim.keymap.set("n", "<leader>nf", '<cmd>let @+ = expand("%:t")<cr>', { noremap = true, silent = true, desc = "Copy filename to clipboard" })

-- Clear search highlights
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { noremap = true, silent = true, desc = "Clear search highlights" })

-- Close the quickfix window
vim.keymap.set("n", "<leader>q", "<cmd>cclose<cr>", { noremap = true, silent = true, desc = "Close quickfix" })

-- QOL
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { noremap = true, silent = true, desc = "Save file" })

-- Center the screen when searching
vim.keymap.set("n", "n", "nzz", { noremap = true, silent = true, desc = "Next search result (centered)" })
vim.keymap.set("n", "N", "Nzz", { noremap = true, silent = true, desc = "Prev search result (centered)" })

-- Navigate splits
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true, desc = "Move to split above" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true, desc = "Move to left split" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true, desc = "Move to split below" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true, desc = "Move to right split" })

-- Resize splits
vim.keymap.set("n", "<C-A-l>", ":vert res +3 <CR>", { noremap = true, silent = true, desc = "Increase split width" })
vim.keymap.set("n", "<C-A-h>", ":vert res -3 <CR>", { noremap = true, silent = true, desc = "Decrease split width" })
vim.keymap.set("n", "<C-A-j>", ":res +3 <CR>", { noremap = true, silent = true, desc = "Increase split height" })
vim.keymap.set("n", "<C-A-k>", ":res -3 <CR>", { noremap = true, silent = true, desc = "Decrease split height" })

-- Navigate buffers (using ]b/[b to preserve <C-i> jumplist navigation)
vim.keymap.set("n", "]b", ":bnext<CR>", { noremap = true, silent = true, desc = "Next buffer" })
vim.keymap.set("n", "[b", ":bprev<CR>", { noremap = true, silent = true, desc = "Previous buffer" })

-- Move a highlighted line up or down 1 line
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection up" })

-- Keep cursor in place when removing the line break at the end of a line
vim.keymap.set("n", "J", "mzJ`z", { noremap = true, silent = true, desc = "Join lines (cursor stays)" })

-- While in highlight mode, delete the highlighted text and paste the yanked text
vim.keymap.set("x", "<leader>p", "\"_dP", { noremap = true, silent = true, desc = "Paste over selection without yanking" })

-- Delete into the void
vim.keymap.set("n", "<leader>d", "\"_d", { noremap = true, silent = true, desc = "Delete into void register" })
vim.keymap.set("v", "<leader>d", "\"_d", { noremap = true, silent = true, desc = "Delete into void register" })

-- Yank into the system clipboard, awesome
vim.keymap.set("n", "<leader>y", "\"+y", { noremap = true, silent = true, desc = "Yank to system clipboard" })
vim.keymap.set("v", "<leader>y", "\"+y", { noremap = true, silent = true, desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", "\"+Y", { noremap = true, silent = true, desc = "Yank line to system clipboard" })

-- Tab keymaps
vim.keymap.set("n", "<leader>tn", "<cmd>.tabnew<cr>", { noremap = true, silent = true, desc = "New tab" })
vim.keymap.set("n", "<leader>te", "<cmd>tabc<cr>", { noremap = true, silent = true, desc = "Close tab" })
vim.keymap.set("n", "<leader>to", "<cmd>tabo<cr>", { noremap = true, silent = true, desc = "Close other tabs" })

-- Execute lua inline
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<cr>", { noremap = true, silent = true, desc = "Source current file" })
vim.keymap.set("n", "<leader>x", ":.lua<cr>", { noremap = true, silent = true, desc = "Execute current line as Lua" })
vim.keymap.set("v", "<leader>x", ":lua<cr>", { noremap = true, silent = true, desc = "Execute selection as Lua" })

-- Quick fix navigation
vim.keymap.set("n", "<A-n>", "<cmd>cnext<cr>", { noremap = true, silent = true, desc = "Next quickfix item" })
vim.keymap.set("n", "<A-p>", "<cmd>cprev<cr>", { noremap = true, silent = true, desc = "Prev quickfix item" })

-- Close a buffer
vim.keymap.set("n", "<leader>cb", "<cmd>bdel!<cr>", { noremap = true, silent = true, desc = "Close buffer" })

-- Auto-correct spelling to first suggestion
vim.keymap.set("n", "z/", function()
    vim.cmd('normal 1z=')
end, { noremap = true, silent = true, desc = "Auto-correct word to first suggestion" })

-- Insert current date and time
vim.keymap.set("n", "<leader>tt", function()
    local datetime = os.date("%Y-%m-%d %H:%M:%S")
    vim.api.nvim_put({ datetime }, "c", true, true)
    vim.cmd('normal! o')
    vim.cmd('startinsert')
end, { noremap = true, silent = true, desc = "Insert current date and time" })

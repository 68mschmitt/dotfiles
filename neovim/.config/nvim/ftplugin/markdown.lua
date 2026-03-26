-- Insert horizontal rule and drop to new line
vim.keymap.set("i", "<C-h>", "---<cr><esc>o", {
    noremap = true,
    silent = true,
    buffer = true,
    desc = "Insert horizontal rule",
})

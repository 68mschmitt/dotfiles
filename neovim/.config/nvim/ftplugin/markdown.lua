-- Prose formatting
vim.bo.textwidth = 100
vim.opt_local.formatoptions:append("t") -- auto-wrap text at textwidth
vim.opt_local.linebreak = true          -- wrap at word boundaries when 'wrap' is on
vim.opt_local.wrap = true               -- Set wrap on for md files that overflow

-- Insert horizontal rule and drop to new line
vim.keymap.set("i", "<C-h>", "---<cr><esc>o", {
    noremap = true,
    silent = true,
    buffer = true,
    desc = "Insert horizontal rule",
})

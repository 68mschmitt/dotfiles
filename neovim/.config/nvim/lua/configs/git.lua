return {
    {
        'lewis6991/gitsigns.nvim',
        event = { "BufReadPre", "BufWritePre" },
        opts = {
            current_line_blame = true,
        }
    },

    {
        'tpope/vim-fugitive',
        config = function()
            vim.keymap.set("n", "<leader>gs", vim.cmd.Git);
        end
    },
}

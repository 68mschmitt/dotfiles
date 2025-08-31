local project_runner = {
    '68mschmitt/project_runner.nvim',
    lazy = false,
    dev = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { autogenerate = false },
    init = function()
        vim.api.nvim_set_keymap("n", "<leader>pr", "<cmd>ProjectRunnerKillAll<CR><cmd>ProjectRunnerSelect<CR>", { noremap = true, silent = true });
        vim.api.nvim_set_keymap("n", "<leader>pk", "<cmd>ProjectRunnerKillAll<CR>", { noremap = true, silent = true });
    end,
}

return {
    -- project_runner,
}

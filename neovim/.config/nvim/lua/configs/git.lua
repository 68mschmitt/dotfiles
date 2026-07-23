local gitsigns =
{
    'lewis6991/gitsigns.nvim',
    event = { "BufReadPre", "BufWritePre" },
    opts = {
        current_line_blame = true,
    }
};

local fugitive = {
    'tpope/vim-fugitive',
    config = function()
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git);
    end
};

local octo = {
    'pwntester/octo.nvim',
    cmd = "Octo",
    dependencies = {
        'nvim-lua/plenary.nvim',
        'folke/snacks.nvim',
        'nvim-tree/nvim-web-devicons',
    },
    opts = function()
        -- Highlight PR/issue buffers as markdown
        vim.treesitter.language.register("markdown", "octo")
        return {
            -- "default" = vim.ui.select (styled by snacks via ui_select=true).
            -- The snacks picker previews octo:// buffers and races its async
            -- gh load -> "Invalid buffer id". octo exposes no preview toggle.
            picker = "default",
            enable_builtin = true,
        }
    end,
    keys = {
        { "<leader>gr", "<cmd>Octo pr list<cr>", desc = "Octo: review PRs" },
        { "<leader>gO", "<cmd>Octo<cr>",         desc = "Octo: command palette" },
    },
};

return {
    gitsigns,
    fugitive,
    octo
}

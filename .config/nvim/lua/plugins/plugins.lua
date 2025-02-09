return {
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        lazy = false,
        dependencies = { { 'nvim-lua/plenary.nvim' } },
        config = function() require("configs.telescope") end
    },

    {
        'nvim-treesitter/nvim-treesitter',
        lazy = false,
        config = function() require("configs.treesitter") end,
    },

    { 'nvim-treesitter/playground' },

    {
        'ThePrimeagen/harpoon',
        lazy = false,
        config = function() require("configs.harpoon") end
    },

    {
        'mbbill/undotree',
        lazy = false,
        config = function() require("configs.undotree") end
    },

    {
        'tpope/vim-fugitive',
        lazy = false,
        config = function() require("configs.fugitive") end
    },

    {
        'neovim/nvim-lspconfig',
        lazy = true,
        config = function() require("configs.lsp") end
    },

    { 'hrsh7th/nvim-cmp' },

    { 'hrsh7th/cmp-nvim-lsp' },

    {
        'williamboman/mason.nvim',
        lazy = false,
        config = function() require("configs.mason") end
    },

    { 'williamboman/mason-lspconfig.nvim' },

    {
        'mfussenegger/nvim-dap',
        config = function() require("configs.nvim-dap") end
    },

    {
        'seblj/roslyn.nvim',
        lazy = true,
        dev = true,
        ft = "cs",
        events = { 'BufReadPre', 'BufNewFile' },
        opts = {
            filewatching = true,
            broad_search = true,
            lock_target = true,
        },
        init = require('configs.roslyn').init()
    },

    {
        'rcarriga/nvim-dap-ui',
        dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
        config = function() require("configs.dapui") end
    },

    {
        'lewis6991/gitsigns.nvim',
        config = require('configs.gitsigns'),
    },

    -- Random Fun
    {
        'alec-gibson/nvim-tetris',
        config = function() require('configs.random').tetris() end
    },
    {
        'eandrju/cellular-automaton.nvim',
        config = function() require('configs.random').cellular_automaton() end
    },
    {
        'tamton-aquib/duck.nvim',
        config = function()
            vim.keymap.set('n', '<leader>dd', function() require("duck").hatch() end, {})
            vim.keymap.set('n', '<leader>dk', function() require("duck").cook() end, {})
            vim.keymap.set('n', '<leader>da', function() require("duck").cook_all() end, {})
        end
    },
    {
        "letieu/hacker.nvim",
    },
    {
        'NStefan002/donut.nvim'
    },
}

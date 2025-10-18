local tetris =
{
    'alec-gibson/nvim-tetris',
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>tet", function() vim.cmd("Tetris") end)
    end
};

local custom_cellular_automaton = {
    '68mschmitt/custom-cellular-automata.nvim',
    dev = true,
    dependencies = { 'eandrju/cellular-automaton.nvim' },
    lazy = false,
    config = function()
        require('custom-cellular-automaton').setup()
        vim.keymap.set("n", "<leader>mir", function() vim.cmd([[CellularAutomaton make_it_rain]]) end)
        vim.keymap.set("n", "<leader>sbl", function() vim.cmd([[CellularAutomaton scramble]]) end)
        vim.keymap.set("n", "<leader>gol", function() vim.cmd([[CellularAutomaton game_of_life]]) end)
        vim.keymap.set("n", "<leader>wis", function() vim.cmd([[CellularAutomaton wisp]]) end)
        vim.keymap.set("n", "<leader>fw", function() vim.cmd([[CellularAutomaton fireworks]]) end)
    end
};

local wowmode = {
    "68mschmitt/wowmode.nvim",
    dev = true,
    config = function()
        require("wowmode").preset("presentation") -- or "subtle" / default
        require("wowmode").start()
        -- map quick toggle
        vim.keymap.set("n", "<leader>wo", "<cmd>WowStart<cr>")
        vim.keymap.set("n", "<leader>wx", "<cmd>WowStop<cr>")
    end
}

local devdocs_client = {
    "luckasRanarison/nvim-devdocs",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    opts = {}
}

return {
    tetris,
    custom_cellular_automaton,
    devdocs_client,
}

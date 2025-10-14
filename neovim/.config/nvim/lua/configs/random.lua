local tetris =
{
    'alec-gibson/nvim-tetris',
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>tet", function() vim.cmd("Tetris") end )
    end
};

local cellular_automaton = {
    'eandrju/cellular-automaton.nvim',
    lazy = false,
    config = function()
        require('configs.cellular-automaton.horizontal-slide').register()
        require('configs.cellular-automaton.slide-left').register()
        require('configs.cellular-automaton.fireworks').register()
        require('configs.cellular-automaton.matrix').register()
        require('configs.cellular-automaton.snowfall').register()
        require('configs.cellular-automaton.ripple').register()
        require('configs.cellular-automaton.blackhole').register()
        require("configs.cellular-automaton.snowtown").register()
        require("configs.cellular-automaton.runner").register()
        require('configs.cellular-automaton.updraft').register()
        require('configs.cellular-automaton.ember-rise').register()
        require('configs.cellular-automaton.glitch_drift').register()
        require('configs.cellular-automaton.star-wars').register()
        require('configs.cellular-automaton.wisp').register()
        require('configs.cellular-automaton.inferno').register()
        vim.keymap.set("n", "<leader>mir", function() vim.cmd([[CellularAutomaton make_it_rain]]) end )
        vim.keymap.set("n", "<leader>sbl", function() vim.cmd([[CellularAutomaton scramble]]) end )
        vim.keymap.set("n", "<leader>gol", function() vim.cmd([[CellularAutomaton game_of_life]]) end )
        vim.keymap.set("n", "<leader>wis", function() vim.cmd([[CellularAutomaton wisp]]) end )
        vim.keymap.set("n", "<leader>fw", function() vim.cmd([[CellularAutomaton fireworks]]) end )
    end
};

local donut = {
    'NStefan002/donut.nvim',
    lazy = false,
    init = function()
        vim.keymap.set("n", "<leader>tet", function() vim.cmd([[Tetris]]) end )
    end
};

return {
    tetris,
    cellular_automaton,
    -- donut
}

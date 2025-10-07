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
        vim.keymap.set("n", "<leader>mir", function() vim.cmd([[CellularAutomaton make_it_rain]]) end )
        vim.keymap.set("n", "<leader>sbl", function() vim.cmd([[CellularAutomaton scramble]]) end )
        vim.keymap.set("n", "<leader>gol", function() vim.cmd([[CellularAutomaton game_of_life]]) end )
        require('configs.cellular-automaton.horizontal-slide')
        require('configs.cellular-automaton.slide-left')
        require('configs.cellular-automaton.fireworks')
        require('configs.cellular-automaton.matrix')
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.updraft'))
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.ember-rise'))
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.glitch_drift'))
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.star-wars'))
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.wisp'))
        require("cellular-automaton").register_animation(require('configs.cellular-automaton.inferno'))
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

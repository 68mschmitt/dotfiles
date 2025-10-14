local tetris =
{
    'alec-gibson/nvim-tetris',
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>tet", function() vim.cmd("Tetris") end )
    end
};

local custom_cellular_automaton = {
    dir = vim.fn.stdpath("config") .. "/custom-cellular-automaton.nvim",
    dependencies = { 'eandrju/cellular-automaton.nvim' },
    lazy = false,
    config = function()
        require('custom-cellular-automaton').setup()
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
    custom_cellular_automaton,
    -- donut
}

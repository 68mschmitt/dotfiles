local tetris =
{
    'alec-gibson/nvim-tetris',
    cmd = "Tetris",
    keys = {
        { "<leader>tet", function() vim.cmd("Tetris") end, desc = "Play Tetris" },
    },
};

local custom_cellular_automaton = {
    '68mschmitt/custom-cellular-automata.nvim',
    dev = true,
    dependencies = { '68mschmitt/cellular-automaton.nvim', dev = true },
    cmd = "CellularAutomaton",
    keys = {
        { "<leader>mir", function() vim.cmd([[CellularAutomaton make_it_rain]]) end, desc = "Make it rain" },
        { "<leader>sbl", function() vim.cmd([[CellularAutomaton scramble]]) end, desc = "Scramble" },
        { "<leader>gol", function() vim.cmd([[CellularAutomaton game_of_life]]) end, desc = "Game of Life" },
        { "<leader>wis", function() vim.cmd([[CellularAutomaton wisp]]) end, desc = "Wisp" },
        { "<leader>fw", function() vim.cmd([[CellularAutomaton fireworks]]) end, desc = "Fireworks" },
    },
    config = function()
        require('custom-cellular-automaton').setup()
    end
};

return {
    tetris,
    custom_cellular_automaton,
}

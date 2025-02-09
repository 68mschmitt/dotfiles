local M = {}

M.cellular_automaton =
function()
    vim.keymap.set("n", "<leader>mir", function() vim.cmd([[CellularAutomaton make_it_rain]]) end )
    vim.keymap.set("n", "<leader>sbl", function() vim.cmd([[CellularAutomaton scramble]]) end )
    vim.keymap.set("n", "<leader>gol", function() vim.cmd([[CellularAutomaton game_of_life]]) end )
end

M.tetris =
function()
    vim.keymap.set("n", "<leader>tet", function() vim.cmd([[Tetris]]) end )
end

return M;

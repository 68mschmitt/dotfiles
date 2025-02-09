local M = {}

local lspconfig = require("lspconfig")

-- Function to find and prompt user to select a .sln file
M.pick_solution = function(target)
    local cwd = vim.fn.getcwd()
    local solutions = vim.fn.glob(cwd .. "/*.sln", true, true)

    if #solutions == 0 then
        vim.notify("No solution files found!", vim.log.levels.WARN)
        return nil
    elseif #solutions == 1 then
        return solutions[1]  -- Auto-select if only one .sln exists
    else
        -- Create a list of options for the user to pick from
        local options = { "Select a solution file:" }
        for i, path in ipairs(solutions) do
            table.insert(options, string.format("%d: %s", i, path))
        end

        -- Prompt user
        local choice = vim.fn.inputlist(options)

        -- Validate user input
        if choice < 1 or choice > #solutions then
            vim.notify("Invalid selection. Using first solution.", vim.log.levels.WARN)
            return solutions[1]
        end

        return solutions[choice]
    end
end

-- Function to configure the LSP
M.setup_csharp_lsp = function()
    local selected_sln = M.pick_solution()
    if not selected_sln then return end

    vim.notify("Using solution: " .. selected_sln, vim.log.levels.INFO)

    lspconfig.csharp_ls.setup {
        cmd = { "csharp-ls", "--solution", selected_sln },
        root_dir = function()
            return vim.fn.fnamemodify(selected_sln, ":h")
        end,
    }
end

-- Auto-detect and prompt for .sln selection on C# file open
--vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = "*.cs",
--    callback = function()
--        setup_csharp_lsp()
--    end
--})

return M

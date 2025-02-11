local M = {}
M.opts =
{
    config = {
        settings = {
            ["csharp|code_lens"] = {
                dotnet_enable_references_code_lens = true,
            },
        }
    },

    filewatching = true,
    broad_search = true,
    lock_target = true,
};

function M.init()
    vim.keymap.set("n", "<leader>tar", function() vim.cmd([[Roslyn target]]) end )

    vim.keymap.set("n", "<leader>ref", function() vim.lsp.codelens.refresh() end )
end

return M;

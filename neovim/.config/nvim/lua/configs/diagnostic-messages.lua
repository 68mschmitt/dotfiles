-- Diagnostic message display using tiny-inline-diagnostic
-- Shows inline diagnostics from LSP and linters

local diagnostic = {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
        require('tiny-inline-diagnostic').setup({
            options = {
                -- Display events: show diagnostics on LSP attach and when diagnostics change
                -- DiagnosticChanged fires when linters (nvim-lint) report results
                overwrite_events = { "LspAttach", "DiagnosticChanged" }
            }
        })
        vim.diagnostic.config({ virtual_text = false })
    end
}

return {
    diagnostic
}

-- Diagnostic message display using tiny-inline-diagnostic
-- Shows inline diagnostics from LSP and linters

local diagnostic = {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    init = function()
        vim.diagnostic.config({
            virtual_text = false,
            severity_sort = true,
        })
    end,
    opts = {
        options = {
            show_source = true,
            -- Display events: show diagnostics on LSP attach and when diagnostics change
            -- DiagnosticChanged fires when linters (nvim-lint) report results
            overwrite_events = { "LspAttach", "DiagnosticChanged" },
        },
    },
}

return {
    diagnostic
}

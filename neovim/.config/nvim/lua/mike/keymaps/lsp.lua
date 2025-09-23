return {
    setup = function(_, bufnr)
        local opts = { noremap = true, buffer = bufnr }

        vim.keymap.set('n', '<leader>k', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
        vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
        vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
        vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
        vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
        vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
        vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
        vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
        vim.keymap.set({ 'n', 'x' }, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
        vim.keymap.set({ 'n', 'v' }, '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)

        -- Disable/Enable diagnostics
        vim.keymap.set('n', '<leader>dis',
            function()
                vim.diagnostic.enable(not vim.diagnostic.is_enabled())
                local message = "Diagnostics: "
                if vim.diagnostic.is_enabled() then
                    message = message .. "Enabled"
                else
                    message = message .. "Disabled"
                end
                vim.notify(message)
            end
            , opts)
    end
}

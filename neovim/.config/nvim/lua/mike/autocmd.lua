local autocmd = vim.api.nvim_create_autocmd

local group = vim.api.nvim_create_augroup("MikeAuGroup", { clear = true })

autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = group,
    callback = function() require("vim.hl").on_yank({ higroup = "Substitute", timeout = 200 }) end,
})

autocmd("FileType", {
    group = group,
    pattern = "*",
    command = "set formatoptions-=o"
})

autocmd("FileType", {
    group = group,
    pattern = { "text", "tex", "markdown", "md" },
    callback = function()
        if vim.bo.buftype ~= "nofile" then
            vim.wo[0][0].spell = true
        end
    end
})

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.vil",
    command = "set filetype=json",
})

local keymap_setup = function(_, bufnr)
    local opts = function(desc)
        return { noremap = true, buffer = bufnr, desc = desc }
    end

    vim.keymap.set('n', '<leader>k', '<cmd>lua vim.lsp.buf.hover()<cr>', opts("LSP Hover"))
    vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts("Signature Help"))
    vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts("LSP Rename"))
    vim.keymap.set({ 'n', 'x' }, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts("LSP Format"))
    vim.keymap.set({ 'n', 'v' }, '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts("Code Action"))
end

autocmd("LspAttach", {
    desc = "LSP options and keymaps",
    group = group,
    callback = function(event)
        local id = vim.tbl_get(event, "data", "client_id")
        local client = id and vim.lsp.get_clients({ id = id })[1]

        if not client then return end

        keymap_setup(client, event.buf)

        if client:supports_method("textDocument/codeLens") then
            autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
                buffer = event.buf,
                callback = function() vim.lsp.codelens.enable(true) end,
            })
        end

        if client:supports_method("textDocument/documentHighlight") then
            autocmd({ "CursorHold", "CursorHoldI" }, {
                buffer = event.buf,
                group = group,
                callback = vim.lsp.buf.document_highlight,
            })

            autocmd({ "CursorMoved", "CursorMovedI" }, {
                buffer = event.buf,
                group = group,
                callback = vim.lsp.buf.clear_references,
            })

            autocmd("LspDetach", {
                group = group,
                buffer = event.buf,
                callback = function(ev)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds({ group = group, buffer = ev.buf })
                end,
            })
        end
    end,
})

local jsx_group = vim.api.nvim_create_augroup("ReactJSX", { clear = true })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = jsx_group,
    pattern = "*.js",
    callback = function()
        -- Search for an HTML tag in the buffer
        for i = 1, math.min(100, vim.fn.line("$")) do
            local line = vim.fn.getline(i)
            if line:find("<[A-Za-z]") then
                vim.bo.filetype = "javascriptreact"
                break
            end
        end
    end,
})



local autocmd = vim.api.nvim_create_autocmd

local group = vim.api.nvim_create_augroup("MikeAuGroup", { clear = true })

autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = group,
    callback = function() require("vim.hl").on_yank({ higroup = "Substitute", timeout = 200 }) end,
})

autocmd("FileType", {
    group = group,
    pattern = "cs",
    command = "compiler dotnet",
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

autocmd("LspAttach", {
    desc = "LSP options and keymaps",
    group = group,
    callback = function(event)
        local id = vim.tbl_get(event, "data", "client_id")
        local client = id and vim.lsp.get_client_by_id(id)

        if not client then return end

        require("mike.keymaps.lsp").setup(client, event.buf)

        if client:supports_method("textDocument/codeLens") then
            autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
                buffer = event.buf,
                callback = function(ev) vim.lsp.codelens.refresh({ bufnr = ev.buf }) end,
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


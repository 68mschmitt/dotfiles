local lspconfig = { "neovim/nvim-lspconfig" };

local mason = {
    "mason-org/mason.nvim",
    opts =
    {
        registries = {
            "github:mason-org/mason-registry",
            "github:Crashdummyy/mason-registry",
        },
    },
    cmd = "Mason",
};

local masonLspconfig = {
    "mason-org/mason-lspconfig.nvim",
    opts = {
        handlers = { vim.lsp.enable },
    },
    event = { "BufReadPre", "BufNewFile" },
    dependencies =
    {
        lspconfig,
        mason
    },
};

local schemastore = { "b0o/schemastore.nvim", lazy = true };


local lazydev = {
    "folke/lazydev.nvim",
    ft = "lua",
    opts =
    {
        library =
        {
            { path = "${3rd}/luv/library",     words = { "vim%.uv" } },
            { path = "${3rd}/busted/library" },
            { path = "${3rd}/luassert/library" },
            { path = "snacks.nvim",            words = { "Snacks" } },
            { path = "nvim-test" },
        },
    },
};

local linter = {
    "mfussenegger/nvim-lint",
    event = { "BufWritePost", "BufEnter", "InsertLeave" },
    opts = {
        linters_by_ft = {
            markdown = { "writegood" }
        },
    },
    config = function(_, opts)
        local lint = require("lint")

        -- Define custom write-good linter
        lint.linters.writegood = {
            name = "writegood-linter",
            cmd = "write-good",
            stdin = false,
            stream = "stdout",
            ignore_exitcode = true,
            args = {},
            parser = function(output, _)
                local diagnostics = {}
                -- Only process non-empty output
                if output and #output > 0 then
                    for line in output:gmatch("[^\n]+") do
                        local ln, col = line:match('on line (%d+) at column (%d+)')
                        if ln and col then
                            table.insert(diagnostics, {
                                lnum = tonumber(ln) - 1,
                                col = tonumber(col) - 1,
                                message = line,
                                severity = vim.diagnostic.severity.WARN,
                            })
                        end
                    end
                end
                return diagnostics
            end,
        }

        lint.linters_by_ft = opts.linters_by_ft

        -- Create autocmd to run linter on specified events
        vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
            group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
            callback = function(event)
                -- Get the current buffer's filetype
                local ft = vim.bo[event.buf].filetype
                -- Only lint if this filetype has a linter configured
                if lint.linters_by_ft[ft] then
                    lint.try_lint()
                end
            end,
        })
    end
};

return {
    mason,
    masonLspconfig,
    schemastore,
    lazydev,
    linter,
}

local lspconfig = { "neovim/nvim-lspconfig" }

local mason = {
    "mason-org/mason.nvim",
    opts = {
        registries = {
            "github:mason-org/mason-registry",
            "github:Crashdummyy/mason-registry",
        },
    },
    cmd = "Mason",
}

local masonLspconfig = {
    "mason-org/mason-lspconfig.nvim",
    opts = {
        handlers = { vim.lsp.enable },
    },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        lspconfig,
        mason
    },
}

local schemastore = { "b0o/schemastore.nvim", lazy = true }

local lazydev = {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
        library = {
            { path = "${3rd}/luv/library",     words = { "vim%.uv" } },
            { path = "${3rd}/busted/library" },
            { path = "${3rd}/luassert/library" },
            { path = "snacks.nvim",            words = { "Snacks" } },
            { path = "nvim-test" },
        },
    },
}

-- Simplified nvim-lint configuration using built-in linters
local linter = {
    "mfussenegger/nvim-lint",
    event = { "BufWritePost", "BufEnter", "InsertLeave" },
    config = function()
        local lint = require("lint")

        -- Configure which linters to use for each filetype
        -- Using nvim-lint's built-in linter names
        lint.linters_by_ft = {
            markdown = { "write_good" },
            -- Add more linters as needed:
            -- python = { "pylint" },
            -- lua = { "luacheck" },
        }

        -- Create autocmd to run linter on specified events
        vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
            group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
            callback = function(event)
                local ft = vim.bo[event.buf].filetype
                if lint.linters_by_ft[ft] then
                    lint.try_lint()
                end
            end,
        })
    end
}

return {
    mason,
    masonLspconfig,
    schemastore,
    lazydev,
    linter,
}

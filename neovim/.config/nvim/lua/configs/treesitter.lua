local treesitter = {
    {
        'nvim-treesitter/nvim-treesitter',
        branch = 'main',
        build = ":TSUpdate",
        lazy = false,
        config = function()
            require('nvim-treesitter').setup({})

            -- Install parsers (no-op if already installed)
            require('nvim-treesitter').install({
                "c",
                "c_sharp",
                "commonlisp",
                "html",
                "javascript",
                "json",
                "lua",
                "markdown",
                "markdown_inline",
                "query",
                "regex",
                "tsx",
                "typescript",
                "typst",
                "vim",
                "vimdoc",
                "yaml"
            })

            -- Highlighting is now native neovim — enable it for all filetypes
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(ev)
                    pcall(vim.treesitter.start, ev.buf)
                end,
            })
        end
    },
}

local treesitter_context = {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("treesitter-context").setup({
            enable = true,
            multiwindow = false,
            max_lines = 0,
            min_window_height = 0,
            line_numbers = true,
            multiline_threshold = 20,
            trim_scope = "outer",
            mode = "cursor",
            separator = nil,
            zindex = 20,
            on_attach = nil,
        })
    end
}

return {
    treesitter,
    treesitter_context,
}

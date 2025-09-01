local utils = require("mike.utils");

local treesitter = {
    {
        'nvim-treesitter/nvim-treesitter',
        build = ":TSUpdate",
        config = function()
            if utils.isWindows() then
                require('nvim-treesitter.install').compilers = {"zig"}
            end
            require('nvim-treesitter.configs').setup({
                -- A list of parser names, or "all" (the listed parsers MUST always be installed)
                ensure_installed = { "regex", "javascript", "typescript", "c_sharp", "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "json" },
                ignore_install={},
                modules={},
                -- Install parsers synchronously (only applied to `ensure_installed`)
                sync_install = true,

                -- Automatically install missing parsers when entering buffer
                -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
                auto_install = true,

                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },
            })
        end
    },
    { 'nvim-treesitter/playground' },
}

return {
    treesitter
}

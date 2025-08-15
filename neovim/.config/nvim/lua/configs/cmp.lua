return {
    'saghen/blink.cmp',
    dependencies = {
        'rafamadriz/friendly-snippets',
        'L3MON4D3/LuaSnip'
    },
    version = '*',
    opts = {
        keymap = { preset = 'default' },
        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = 'mono'
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' }
        },
    },
    opts_extend = { "sources.default" },
    config = function(_, opts)
        require("blink.cmp").setup(opts)
        local vs_code_snip = require("luasnip.loaders.from_vscode")
        vs_code_snip.lazy_load()
        vs_code_snip.lazy_load({
            paths = vim.fn.stdpath("config") .. "/snippets/"
        })
    end
}

local blink = {
    'saghen/blink.cmp',
    dependencies = {
        'rafamadriz/friendly-snippets',
    },
    version = '*',
    opts = {
        keymap = {
            preset = 'default',
            ["<C-n>"] = { "show", "select_next", "fallback" },
            ["<C-p>"] = { "show", "select_prev", "fallback" }
        },
        completion = {
            menu = {
                auto_show = true,
                draw = {
                    columns = {
                        { "label", "label_description", gap = 1 },
                        { "kind_icon", "kind" }
                    },
                }
            },
            ghost_text = { enabled = false },
        },
        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = 'mono'
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' }
        },
    },
    opts_extend = { "sources.default" },
};

return {
    blink
}

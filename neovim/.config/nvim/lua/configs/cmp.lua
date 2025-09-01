local friendly_snippets = { 'rafamadriz/friendly-snippets' }

local luasnip = { 'L3MON4D3/LuaSnip' }

local blink = {
    'saghen/blink.cmp',
    dependencies = {
        luasnip,
        friendly_snippets,
        lspkind_plugin
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
                auto_show = false,
                draw = {
                    columns = {
                        { "label", "label_description", gap = 1 },
                        { "kind_icon", "kind" }
                    },
                }
            },
            ghost_text = { enabled = true },
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
    config = function(_, opts)
        local cmp = require("blink.cmp")
        cmp.setup(opts)
        local vs_code_snip = require("luasnip.loaders.from_vscode")
        vs_code_snip.lazy_load()
        vs_code_snip.lazy_load({
            paths = vim.fn.stdpath("config") .. "/snippets/"
        })
    end
};

return {
    blink
}

-- LSP CONFIG --
return
{
    {
        "mason-org/mason-lspconfig.nvim",
        opts = { 
            handlers = { vim.lsp.enable },
        },
        event = { "BufReadPre", "BufNewFile" },
        dependencies =
        {
            { "neovim/nvim-lspconfig" },
            {
                "mason-org/mason.nvim",
                opts = 
                {
                    registries = {
                        "github:mason-org/mason-registry",
                        "github:Crashdummyy/mason-registry",
                    },
                },
                cmd = "Mason",
                dependencies = { "roslyn.nvim" }
            },
        },
    },
    { "seblyng/nvim-lsp-extras" },
    { "b0o/schemastore.nvim", lazy = true },
    { "onsails/lspkind.nvim", lazy = true },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts =
        {
            library =
            {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                { path = "${3rd}/busted/library" },
                { path = "${3rd}/luassert/library" },
                { path = "snacks.nvim", words = { "Snacks" } },
                { path = "nvim-test" },
            },
        },
    },
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        opts = {
            ensure_installed = {
                "prettier",
                "roslyn",
                "lua_ls",
                "clangd",
                "gopls",
                "ts_ls",
            },
            auto_update = true,
        }
    },
}

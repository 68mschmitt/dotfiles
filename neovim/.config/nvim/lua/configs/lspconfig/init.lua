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
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            { path = "${3rd}/busted/library" },
            { path = "${3rd}/luassert/library" },
            { path = "snacks.nvim", words = { "Snacks" } },
            { path = "nvim-test" },
        },
    },
};

return {
    mason,
    masonLspconfig,
    schemastore,
    lazydev
}

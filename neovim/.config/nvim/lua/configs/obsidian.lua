local plenary = { "nvim-lua/plenary.nvim" };

local obsidian = {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = { plenary },
    opts = {
        ui = { enable = false },
        workspaces = {
            {
                name = "personal",
                path = "~/projects/second-brain/Vault/Vault/",
            },
        },
        picker = {
            name = "snacks.pick"
        },
        legacy_commands = false,
    },
    init = function()
        vim.opt.conceallevel = 1
    end,
};

return {
    obsidian
}

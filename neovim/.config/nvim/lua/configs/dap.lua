local dapuiImport =
{
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" }
};

local dapImport = {
    "mfussenegger/nvim-dap",
    config = function()
        -- Optional: dap keymaps here
    end,
};

local masonImport = { "williamboman/mason.nvim" };

local mason_dapImport = {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
        masonImport,
        dapImport
    },
    config = function()
        local dap, dapui = require("dap"), require("dapui")

        dapui.setup()

        require("mason-nvim-dap").setup({
            automatic_installation = false,
            ensure_installed = { "coreclr" },
            handlers = {
                function(config)
                    require("mason-nvim-dap").default_setup(config)
                end,
            },
        })

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end
    end,
};

return {
    -- dapuiImport,
    -- dapImport,
    -- mason_dapImport
}

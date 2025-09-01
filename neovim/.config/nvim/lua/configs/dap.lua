local dapui =
{
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" }
};

local dap = {
    "mfussenegger/nvim-dap",
    config = function()
        -- Optional: dap keymaps here
    end,
};

local mason = { "williamboman/mason.nvim" }

local mason_dap = {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
        mason,
        dap
    },
    config = function()
        local dap, dapui = require("dap"), require("dapui")

        dapui.setup()

        require("mason-nvim-dap").setup({
            -- ensure_installed = { "coreclr" },
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
},

return {
    dapui,
    dap,
    mason_dap
}

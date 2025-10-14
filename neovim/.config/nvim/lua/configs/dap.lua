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

        -- Dap Keymaps
        vim.keymap.set("n", "<F5>", "<cmd>lua require'dap'.continue()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<F10>", "<cmd>lua require'dap'.step_over()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<F11>", "<cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<F12>", "<cmd>lua require'dap'.step_out()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>b", "<cmd>lua require('dap').toggle_breakpoint()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>B", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: ', { noremap = true, silent = true }), { noremap = true, silent = true })<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>lp", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: ', { noremap = true, silent = true }), { noremap = true, silent = true })<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>dr", "<cmd>lua require'dap'.repl.open()<CR>", { noremap = true, silent = true })
        vim.keymap.set("n", "<leader>dl", "<cmd>lua require'dap'.run_last()<CR>", { noremap = true, silent = true })
    end,
};

return {
    -- dapuiImport,
    -- dapImport,
    -- mason_dapImport
}

return {
    {
        "yetone/avante.nvim",
        build = vim.fn.has("win32") ~= 0
        and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
        or "make",
        event = "VeryLazy",
        version = false, -- Never set this value to "*"! Never!
        ---@module 'avante'
        ---@type avante.Config
        opts = {
            provider = "copilot",
            auto_suggestions_provider = nil,
        },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            --- The below dependencies are optional,
            "echasnovski/mini.pick", -- for file_selector provider mini.pick
            "ibhagwan/fzf-lua", -- for file_selector provider fzf
            "stevearc/dressing.nvim", -- for input provider dressing
            "folke/snacks.nvim", -- for input provider snacks
            "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
            {
                "zbirenbaum/copilot.lua",
                event = "VeryLazy",
                config = function()
                    require('copilot').setup({
                        suggestion = {
                            enabled = true,
                            auto_trigger = true,
                            accept = false
                        },
                        panel = {
                            enabled = false
                        },
                        filetypes = {
                            markdown = true,
                            help = true,
                            html = true,
                            javascript = true,
                            typescript = true,
                            ["*"] = true
                        }
                    })

                    vim.keymap.set("i", '<S-Tab>', function()
                        if require("copilot.suggestion").is_visible() then
                            require("copilot.suggestion").accept()
                        else
                            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
                        end
                    end, {
                    silent = true,
                })
            end
        }, -- for providers='copilot'
        {
            -- Make sure to set this up properly if you have lazy=true
            'MeanderingProgrammer/render-markdown.nvim',
            opts = {
                file_types = { "markdown", "Avante" },
            },
            dependencies = {
                'nvim-treesitter/nvim-treesitter',
                'echasnovski/mini.nvim'
            }, -- if you use the mini.nvim suite
            ft = { "markdown", "Avante" },
        },
    },
},
{
    "ravitemer/mcphub.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    build = "npm install -g mcp-hub@latest",  -- Installs `mcp-hub` node binary globally
    config = function()
        require("mcphub").setup()
    end
}
}

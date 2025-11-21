local snacks = {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@diagnostic disable-next-line: undefined-doc-name
    ---@type snacks.Config
    opts = {
        animate = { enabled = true },
        picker = {
            enabled = true,
            ui_select = true,
            sources =
            {
                explorer = {
                    layout = {
                        layout = {
                            position = "right"
                        }
                    },
                    filter = { hidden = true, ignored = false },
                    hidden = true,
                    ignored = true,
                },
                files = {
                    hidden = true,
                    ignored = true,
                },
            },
        },
        dashboard = require('configs.snacks.dashboard').options(true),
        notifier = { enabled = true, timeout = 3000 },
        notify = { enabled = true },
        explorer = { enabled = true, replace_netrw = true },
        image = { enabled = true },
        input = { enabled = true },
        scratch = { enabled = true },
        scroll = { enabled = false },
        words = { enabled = true },
        terminal = { enabled = true },

        statuscolumn = { enabled = false },
        bigfile = { enabled = false },
        indent = { enabled = false },
        quickfile = { enabled = false },
        scope = { enabled = false },
    },
    keys = require('configs.snacks.picker').Keys,
    init = function()
        vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            callback = function()
                -- Setup some globals for debugging (lazy-loaded)
                _G.dd = function(...)
                    Snacks.debug.inspect(...)
                end
                _G.bt = function()
                    Snacks.debug.backtrace()
                end
                vim.print = _G.dd -- Override print to use snacks for `:=` command

                -- Create some toggle mappings
                Snacks.toggle.option("spell",
                { name = "Spelling" })
                :map("<leader>us")

                Snacks.toggle.option("wrap",
                { name = "Wrap" })
                :map("<leader>uw")

                Snacks.toggle.option("relativenumber",
                { name = "Relative Number" })
                :map("<leader>uL")

                Snacks.toggle.diagnostics()
                :map("<leader>ud")

                Snacks.toggle.line_number()
                :map("<leader>ul")

                Snacks.toggle.option("conceallevel",
                { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
                :map("<leader>uc")

                Snacks.toggle.treesitter()
                :map("<leader>uT")

                Snacks.toggle.option("background",
                { off = "light", on = "dark", name = "Dark Background" })
                :map("<leader>ub")

                Snacks.toggle.inlay_hints()
                :map("<leader>uh")

                Snacks.toggle.indent()
                :map("<leader>ug")

                Snacks.toggle.dim()
                :map("<leader>uD")
            end,
        })
    end

}

return {
    snacks
}

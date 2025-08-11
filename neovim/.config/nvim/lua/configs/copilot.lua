return {
    "olimorris/codecompanion.nvim",
    keys = {
        { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI Toggle [C]hat" },
        { "<leader>an", "<cmd>CodeCompanionChat<cr>", mode = { "n", "v" }, desc = "AI [N]ew Chat" },
        { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI [A]ction" },
        { "<leader>ga", "<cmd>CodeCompanionChat Add<CR>", mode = { "v" }, desc = "AI [A]dd to Chat" },
        -- prompts
        { "<leader>ae", "<cmd>CodeCompanion /explain<cr>", mode = { "v" }, desc = "AI [E]xplain" },
    },
    opts = {},
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "github/copilot.vim",
    },
}

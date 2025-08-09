return {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
        { "nvim-lua/plenary.nvim", branch = "master" },
        {  "github/copilot.vim"  }
    },
    build = "make tiktoken",
    opts = {
        -- See Configuration section for options
    },
    keys = {
        { "<leader>cpe", "<cmd>Copilot enable<cr>",         mode = { "n", "v" }, desc = "Enable Copilot" },
        { "<leader>cpd", "<cmd>Copilot disable<cr>",        mode = { "n", "v" }, desc = "Disable Copilot" },
        { "<leader>cce", "<cmd>CopilotChatExplain<cr>",     mode = { "n", "v" }, desc = "Explain code" },
        { "<leader>ccr", "<cmd>CopilotChatReview<cr>",      mode = { "n", "v" }, desc = "Review code" },
        { "<leader>ccf", "<cmd>CopilotChatFix<cr>",         mode = { "n", "v" }, desc = "Fix Code" },
        { "<leader>cco", "<cmd>CopilotChatOptimize<cr>",	mode = { "n", "v" }, desc = "Optimize Code" },
        { "<leader>ccd", "<cmd>CopilotChatDocs<cr>",		mode = { "n", "v" }, desc = "Generate Docs" },
        { "<leader>ccc", "<cmd>CopilotChatToggle<cr>",		mode = { "n", "v" }, desc = "Toggle CopilotChat" },
        { "<leader>cct", "<cmd>CopilotChatTests<cr>",		mode = { "n", "v" }, desc = "Generate Tests" },
        { "<leader>ccm", "<cmd>CopilotChatCommit<cr>",		mode = { "n", "v" }, desc = "Generate Commit Message" },
    },
}

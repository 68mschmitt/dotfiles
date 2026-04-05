local archeologist = {
    dir = "~/projects/plugins/archeologist.nvim",
    cmd = "Archaeologist",
    keys = {
        { "<leader>ca", "<cmd>Archaeologist<cr>", desc = "Code Archaeologist" },
        { "<leader>ca", ":Archaeologist<cr>", mode = "v", desc = "Code Archaeologist (selection)" },
    },
    opts = {
        provider = "bedrock",
        model = "us.anthropic.claude-sonnet-4-6",
        region = "us-east-1",
        token_env = "AWS_BEARER_TOKEN_BEDROCK",
        -- provider = "ollama",
        -- model = "llama3",
        -- ollama_url = "http://localhost:11434",
        timeout = 30000,
    },
}

return {
    archeologist,
}

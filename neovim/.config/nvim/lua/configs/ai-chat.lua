local ai_chat = {
    "68mschmitt/ai-chat.nvim",
    cmd = { "AiChat", "AiChatOpen", "AiChatSend" },
    dev = true,
    keys = { "<leader>aa", "<leader>ac" },
    config = function()
        require("ai-chat").setup({
            default_provider = "bedrock",
            default_model = "anthropic.claude-opus-4-6-v1",
        })
    end,
}

return {
    ai_chat,
}

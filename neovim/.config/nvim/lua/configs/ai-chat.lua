local ai_chat = {
    "68mschmitt/ai-chat.nvim",
    cmd = { "AiChat", "AiChatOpen", "AiChatSend" },
    keys = { "<leader>aa", "<leader>ac" },
    config = function()
        require("ai-chat").setup({
            default_provider = "ollama",
            default_model = "llama3.2",
        })
    end,
}

return {
    ai_chat
}

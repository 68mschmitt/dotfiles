local marginalia = {
  "68mschmitt/marginalia.nvim",
  event = "VeryLazy",
  opts = function()
    return {
      providers = { require("marginalia.providers.diagnostic") },
      keys = {
        toggle   = "<leader>ma",
        next     = "]m",
        prev     = "[m",
        expand   = "<leader>me",
        float    = "<leader>mf",
        loclist  = "<leader>ml",
      },
      auto_attach = true,
    }
  end,
}

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
    -- ai_chat,
    -- marginalia,
}

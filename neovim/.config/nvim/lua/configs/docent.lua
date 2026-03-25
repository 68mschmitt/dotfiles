local docent = {
    "68mschmitt/docent.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DocentReview", "DocentSummary", "DocentDiff" },
    keys = {
        { "<leader>pr", ":DocentReview ", desc = "Docent: AI PR Review" },
    },
    opts = {
        -- opencode_url = "http://localhost:4096", -- or auto-detect
        -- gh_cmd = "gh",
        -- layout = { finding_list_width = 34, note_panel_height = 12 },
    },
}

return {
    docent
}

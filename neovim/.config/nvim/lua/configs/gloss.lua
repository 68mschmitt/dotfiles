local gloss = {
  "68mschmitt/gloss.nvim",
  cmd = {
    "GlossAdd", "GlossDelete", "GlossEdit", "GlossToggle",
    "GlossToggleAll", "GlossNext", "GlossPrev", "GlossAttach",
    "GlossList",
  },
  keys = {
    { "<leader>ga", "<cmd>GlossAdd<cr>", mode = { "n", "v" }, desc = "Add gloss" },
    { "<leader>gd", "<cmd>GlossDelete<cr>", desc = "Delete gloss" },
    { "<leader>ge", "<cmd>GlossEdit<cr>", desc = "Edit gloss" },
    { "<leader>gt", "<cmd>GlossToggle<cr>", desc = "Toggle gloss" },
    { "<leader>gT", "<cmd>GlossToggleAll<cr>", desc = "Toggle all glosses" },
    { "<leader>gn", "<cmd>GlossNext<cr>", desc = "Next gloss" },
    { "<leader>gp", "<cmd>GlossPrev<cr>", desc = "Previous gloss" },
    { "<leader>gl", "<cmd>GlossList<cr>", desc = "List glosses" },
  },
  opts = {},
}

return {
    gloss,
}

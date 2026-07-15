local painfully_slow = {
  "68mschmitt/painfully-slow.nvim",
  cmd = "PainfullySlow",
  keys = {
    { "<leader>ps", "<cmd>PainfullySlow toggle<cr>", desc = "Painfully Slow: toggle mode" },
    { "<leader>pt", "<cmd>PainfullySlow training<cr>", desc = "Painfully Slow: training mode" },
    { "<leader>pa", "<cmd>PainfullySlow always<cr>", desc = "Painfully Slow: always-slow mode" },
    { "<leader>po", "<cmd>PainfullySlow off<cr>", desc = "Painfully Slow: off" },
    { "<leader>pS", "<cmd>PainfullySlow status<cr>", desc = "Painfully Slow: status" },
  },
  opts = {},
}

return {
    painfully_slow,
}

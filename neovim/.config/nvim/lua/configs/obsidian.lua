return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/projects/second-brain/Vault/",
      },
    },
    picker = {
        name = "snacks.pick"
    },
    legacy_commands = false,
  },
  init = function()
      vim.opt.conceallevel = 1
  end,
}

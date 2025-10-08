local memory_palace = {
    '68mschmitt/memory-palace.nvim',
    dev = true,
    lazy = false,
    cmd = { "NewNote", "SortNote" },
    keys = {
        { "<leader>nn", "<cmd>NewNote<cr>",  desc = "New note (inbox)" },
        { "<leader>ns", "<cmd>SortNote<cr>", desc = "Sort/move note" },
    },
    opts = {
        base_dir  = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands",
        inbox_dir = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands/00-Tutorial-Island/tutorial-pen",
    },
}

return {
    memory_palace
}

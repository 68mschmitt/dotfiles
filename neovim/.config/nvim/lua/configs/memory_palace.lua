local note_templates = {
    profile = "# {{title}}\n{{datetime}}\n---\n\n# Personal\n\n# Professional\n\n---\n\n# Follow Up Questions",
}

local memory_palace = {
    '68mschmitt/memory-palace.nvim',
    dev = true,
    lazy = false,
    cmd = { "NewNote", "SortNote" },
    keys = {
        { "<leader>nn", "<cmd>NewNote<cr>",  desc = "New note (inbox)" },
        { "<leader>nc", "<cmd>CreateNote<cr>", desc = "Create new note with intended location" },
        { "<leader>ns", "<cmd>SortNote<cr>", desc = "Sort/move note" },
    },
    opts = {
        base_dir  = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands",
        inbox_dir = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands/00-Tutorial-Island/tutorial-pen",
        templates = note_templates,
    },
}

return {
    memory_palace
}

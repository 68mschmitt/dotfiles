local note_templates = {
    profile =
    "# {{title}}\n{{datetime}}\n---\n\n# Personal\n\n{{content}}\n\n# Professional\n\n---\n\n# Follow Up Questions",
    distill =
    "# {{title}}\n{{datetime}}\n---\n\n{{content}}\n\n# Summarize / Distillation\n---\n- Key takeaways\n- Insights or questions\n- Actions to take\n- Cross-references",
}

local memory_palace = {
    '68mschmitt/memory-palace.nvim',
    dev = true,
    lazy = false,
    cmd = { "NewNote", "SortNote" },
    keys = {
        { "<leader>nn", "<cmd>NewNote<cr>",    desc = "New note (inbox)" },
        { "<leader>nc", "<cmd>CreateNote<cr>", desc = "Create new note with intended location" },
        { "<leader>ns", "<cmd>SortNote<cr>",   desc = "Sort/move note" },
    },
    opts = {
        base_dir  = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands",
        inbox_dir = "~/projects/second-brain/Vault/Vault/MemoryPalaceRPG/Islands/00-Tutorial-Island/tutorial-pen",
        templates = note_templates,
    },
}

local dirquest = {
    '68mschmitt/dirquest.nvim',
    dev = true,
}

local thoughtworks = {
    '68mschmitt/thoughtworks.nvim',
    dev = true,
    lazy = false,
    opts = {
        root_dir = vim.fn.expand("~/projects/second-brain/thoughtworks"),
        inbox_dir = "inbox",
        keymaps = {
            enabled = true,
            prefix = "<leader>n",
        }
    },
}

return {
    -- memory_palace,
    dirquest,
    thoughtworks
}

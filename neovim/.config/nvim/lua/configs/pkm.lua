-- Personal Knowledge Management

local katasync = {
    '68mschmitt/katasync.nvim',
    dev = true,
    lazy = false,
    cmd = { "NewNote", "SortNote" },
    keys = {
        { "<leader>nn", "<cmd>NewNote<cr>",    desc = "New note (inbox)" },
        { "<leader>nc", "<cmd>CreateNote<cr>", desc = "Create new note with intended location" },
        { "<leader>ns", "<cmd>SortNote<cr>",   desc = "Sort/move note" },
        { "<leader>ni", "<cmd>ListInbox<cr>",   desc = "List Inbox Items" },
    },
    opts = {
        base_dir  = "~/projects/second-brain/thoughtworks",
        inbox_dir = "~/projects/second-brain/thoughtworks/inbox",
        templates_dir = "~/projects/second-brain/thoughtworks/templates",  -- where template files live
    },
}

-- For `plugins/markview.lua` users.
local markview = {
    "OXY2DEV/markview.nvim",
    lazy = false,
    dependencies = { "saghen/blink.cmp" },
};

return {
    katasync,
    markview,
}

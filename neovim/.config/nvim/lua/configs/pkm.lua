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
    opts = {
        highlight_groups = function()
            -- Load carbonfox palette with graceful fallback
            local ok, palette = pcall(function()
                return require("nightfox.palette").load("carbonfox")
            end)
            
            if not ok then
                return {} -- Fallback to markview defaults if palette unavailable
            end
            
            -- Helper to darken colors for backgrounds
            local function darken(hex, amount)
                local r = tonumber(hex:sub(2, 3), 16)
                local g = tonumber(hex:sub(4, 5), 16)
                local b = tonumber(hex:sub(6, 7), 16)
                r = math.floor(r * (1 - amount))
                g = math.floor(g * (1 - amount))
                b = math.floor(b * (1 - amount))
                return string.format("#%02x%02x%02x", r, g, b)
            end
            
            local groups = {}
            
            -- Semantic callout groups
            groups.MarkviewBlockQuoteError = { fg = palette.red.base, bg = darken(palette.red.base, 0.85) }
            groups.MarkviewBlockQuoteWarn = { fg = palette.pink.base, bg = darken(palette.pink.base, 0.85) }
            groups.MarkviewBlockQuoteOk = { fg = palette.green.base, bg = darken(palette.green.base, 0.85) }
            groups.MarkviewBlockQuoteNote = { fg = palette.blue.base, bg = darken(palette.blue.base, 0.85) }
            groups.MarkviewBlockQuoteSpecial = { fg = palette.magenta.base, bg = darken(palette.magenta.base, 0.85) }
            groups.MarkviewBlockQuoteDefault = { fg = palette.fg1, bg = palette.bg1 }
            
            -- Palette groups (0-6) for headings and other elements
            local palette_colors = {
                [0] = palette.fg1,        -- Neutral/default
                [1] = palette.red.base,   -- Errors, danger
                [2] = palette.pink.base,  -- Warnings, attention
                [3] = palette.magenta.base, -- Special, important
                [4] = palette.green.base, -- Success, tips
                [5] = palette.blue.base,  -- Notes, info
                [6] = palette.cyan.base,  -- Misc
            }
            
            for i = 0, 6 do
                local color = palette_colors[i]
                local bg = darken(color, 0.90)
                groups["MarkviewPalette" .. i] = { fg = color, bg = bg }
                groups["MarkviewPalette" .. i .. "Fg"] = { fg = color }
                groups["MarkviewPalette" .. i .. "Bg"] = { bg = bg }
                groups["MarkviewPalette" .. i .. "Sign"] = { fg = color }
            end
            
            -- Code block styling
            groups.MarkviewCode = { bg = palette.bg1 }
            groups.MarkviewCodeInfo = { fg = palette.fg1, bg = palette.bg1 }
            groups.MarkviewInlineCode = { bg = darken(palette.fg1, 0.95) }
            
            return groups
        end,
    },
};

return {
    katasync,
    markview,
}

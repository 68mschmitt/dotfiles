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
    config = function()
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
        
        -- Function to apply markview highlights using carbonfox palette
        local function apply_markview_highlights()
            -- Load carbonfox palette with graceful fallback
            local ok, palette = pcall(function()
                return require("nightfox.palette").load("carbonfox")
            end)
            
            if not ok then
                return -- Fallback to markview defaults if palette unavailable
            end
            
            -- Semantic callout groups (using .dim for softer colors)
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteError", { fg = palette.red.dim, bg = darken(palette.red.dim, 0.88) })
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteWarn", { fg = palette.pink.dim, bg = darken(palette.pink.dim, 0.88) })
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteOk", { fg = palette.green.dim, bg = darken(palette.green.dim, 0.88) })
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteNote", { fg = palette.blue.dim, bg = darken(palette.blue.dim, 0.88) })
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteSpecial", { fg = palette.magenta.dim, bg = darken(palette.magenta.dim, 0.88) })
            vim.api.nvim_set_hl(0, "MarkviewBlockQuoteDefault", { fg = palette.fg2, bg = palette.bg1 })
            
            -- Palette groups (0-6) for headings and other elements (using .dim for softer colors)
            local palette_colors = {
                [0] = palette.fg2,        -- Neutral/default (softer)
                [1] = palette.red.dim,    -- Errors, danger
                [2] = palette.pink.dim,   -- Warnings, attention
                [3] = palette.magenta.dim, -- Special, important
                [4] = palette.green.dim,  -- Success, tips
                [5] = palette.blue.dim,   -- Notes, info
                [6] = palette.cyan.dim,   -- Misc
            }
            
            for i = 0, 6 do
                local color = palette_colors[i]
                local bg = darken(color, 0.90)
                vim.api.nvim_set_hl(0, "MarkviewPalette" .. i, { fg = color, bg = bg })
                vim.api.nvim_set_hl(0, "MarkviewPalette" .. i .. "Fg", { fg = color })
                vim.api.nvim_set_hl(0, "MarkviewPalette" .. i .. "Bg", { bg = bg })
                vim.api.nvim_set_hl(0, "MarkviewPalette" .. i .. "Sign", { fg = color })
            end
            
            -- Code block styling
            vim.api.nvim_set_hl(0, "MarkviewCode", { bg = palette.bg1 })
            vim.api.nvim_set_hl(0, "MarkviewCodeInfo", { fg = palette.fg1, bg = palette.bg1 })
            vim.api.nvim_set_hl(0, "MarkviewInlineCode", { bg = darken(palette.fg1, 0.95) })
        end
        
        -- Setup markview with default config
        require("markview").setup({})
        
        -- Apply highlights after colorscheme loads
        vim.api.nvim_create_autocmd("ColorScheme", {
            pattern = "carbonfox",
            callback = apply_markview_highlights,
            desc = "Apply markview highlights for carbonfox colorscheme"
        })
        
        -- Apply highlights immediately if carbonfox is already loaded
        if vim.g.colors_name == "carbonfox" then
            apply_markview_highlights()
        end
    end,
};

return {
    katasync,
    markview,
}

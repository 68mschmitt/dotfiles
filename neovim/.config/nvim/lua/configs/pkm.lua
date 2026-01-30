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
            
            -- Palette colors matching habamax's muted aesthetic
            -- H1-H6 map to Palette1-6, callouts use these semantically
            local palette_colors = {
                [0] = palette.fg2,      -- Neutral/default
                [1] = "#af87af",        -- H1: muted purple (habamax Statement)
                [2] = "#5f87af",        -- H2: muted blue (habamax Type)
                [3] = "#87afaf",        -- H3: muted teal (habamax Identifier)
                [4] = "#5faf5f",        -- H4: muted green (habamax String)
                [5] = "#af875f",        -- H5: muted tan (habamax PreProc)
                [6] = "#d75f87",        -- H6: muted pink (habamax Constant)
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

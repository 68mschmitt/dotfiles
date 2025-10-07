local image_nvim = {
    "3rd/image.nvim",
    opts = {
        (vim.env.TERM_PROGRAM == "Ghostty" and "iterm2") or "kitty", -- default for Kitty
        integrations = {
            markdown = {
                enabled = true,
                clear_in_insert_mode = false,
                download_remote_images = false,
                only_render_image_at_cursor_mode = "inline",
                floating_window = false,
            },
        },
        processor = "magick_cli", -- needs ImageMagick for SVG → bitmap
    },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
}

local render_markdown = {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    -- opts = {
    --     mermaid = {
    --         enabled = true,
    --         options = { "--scale", "2", "-b", "transparent", "-t", "dark" }
    --     }
    -- },
    dependencies = {
        -- image_nvim,
        "nvim-treesitter/nvim-treesitter",
    },
}

return {
    -- render_markdown,
}

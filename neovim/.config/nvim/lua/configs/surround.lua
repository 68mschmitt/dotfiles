local mini_surround = {
    "nvim-mini/mini.surround",
    lazy = false,
    config = function()
        require("mini.surround").setup({
            custom_surroundings = {
                -- Markdown bold: use 'B' to add/delete/replace **text**
                B = {
                    input = { "%*%*().-()%*%*" },
                    output = { left = "**", right = "**" },
                },
                -- Markdown italic: use 'I' to add/delete/replace *text*
                I = {
                    input = { "%*().-()%*" },
                    output = { left = "*", right = "*" },
                },
                -- Markdown inline code: use 'C' to add/delete/replace `text`
                C = {
                    input = { "`().-`()" },
                    output = { left = "`", right = "`" },
                },
            },
        })
    end,
}

return {
    mini_surround,
}

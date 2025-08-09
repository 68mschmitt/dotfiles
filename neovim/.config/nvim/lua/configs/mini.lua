return {
    {
        'echasnovski/mini.statusline',
        config = function()
            require('mini.statusline').setup()
        end
    },
    {
        'echasnovski/mini.tabline',
        dependencies = { 'echasnovski/mini.icons' },
        config = function()
            require('mini.tabline').setup()
        end
    },
}

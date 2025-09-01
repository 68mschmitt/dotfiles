local statusline =
{
    'echasnovski/mini.statusline',
    config = function()
        require('mini.statusline').setup()
    end
};
local tabline = {
    'echasnovski/mini.tabline',
    dependencies = { 'echasnovski/mini.icons' },
    config = function()
        require('mini.tabline').setup()
    end
};

return {
    statusline,
    tabline
}

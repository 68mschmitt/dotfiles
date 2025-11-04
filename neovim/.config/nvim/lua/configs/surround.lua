local mini_surround = {
    "nvim-mini/mini.surround",
    lazy = false,
    config = function()
        require('mini.surround').setup()
    end
}

return {
    mini_surround,
}

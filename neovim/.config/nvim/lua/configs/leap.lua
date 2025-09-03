local leap = {
    "ggandor/leap.nvim",
    Lazy=false,
    config = function()
        require('leap').set_default_mappings()
    end
}

return {
    leap
}

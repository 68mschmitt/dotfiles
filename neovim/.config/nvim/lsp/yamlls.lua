return {
    settings = {
        yaml = {
            schemaStore = {
                -- Disable built-in schemaStore support to use schemastore.nvim
                enable = false,
                url = "",
            },
            schemas = require("schemastore").yaml.schemas(),
            validate = true,
        },
    },
}

local nightfox = {
    'EdenEast/nightfox.nvim',
    lazy = false,
    opts = {
        groups = {
            all = {
                -- Neovim v0.12 treesitter captures that nightfox doesn't define yet.
                -- Without these, they fall back to the generic @keyword color and lose
                -- the distinct styling that predecessor captures had.

                -- @keyword.storage was renamed to @keyword.modifier in v0.12 queries
                ["@keyword.modifier"]           = { link = "StorageClass" },
                -- Type-declaring keywords: class, interface, enum, struct, type
                ["@keyword.type"]               = { link = "Structure" },
                -- async / await
                ["@keyword.coroutine"]          = { link = "@keyword.return" },
                -- Preprocessor directives (#if, #ifdef, "use strict", %YAML)
                ["@keyword.directive"]          = { link = "PreProc" },
                ["@keyword.directive.define"]   = { link = "Define" },
                -- Doc comments (/** */, ///, ---) — same as Comment but explicit
                ["@comment.documentation"]      = { link = "Comment" },

                -- Captures that fall back correctly but are declared explicitly
                -- for completeness and to future-proof against parent changes
                ["@function.call"]              = { link = "Function" },
                ["@function.method"]            = { link = "Function" },
                ["@function.method.call"]       = { link = "Function" },
                ["@module.builtin"]             = { link = "@variable.builtin" },
                ["@variable.parameter.builtin"] = { link = "@variable.parameter" },
                ["@type.definition"]            = { link = "Type" },
                ["@attribute.builtin"]          = { link = "@attribute" },
                ["@tag.builtin"]                = { link = "@tag" },
                ["@string.special.path"]        = { link = "Special" },
                ["@string.special.symbol"]      = { link = "Special" },

                -- Fix LSP semantic token groups that link to undefined targets
                ["@lsp.type.typeAlias"]         = { link = "Type" },
                ["@lsp.typemod.keyword.async"]  = { link = "@keyword.return" },
                ["@lsp.type.unresolvedReference"] = { link = "Error" },
            },
        },
    }
}

return {
    nightfox
}

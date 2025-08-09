return {
    "seblyng/roslyn.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        filewatching = "roslyn",
        lock_target = true,
        broad_search = false,
        choose_target = nil,
    },
    init = function()
        local keymap = vim.keymap.set

        keymap("n", "<leader>tt", "<cmd>Roslyn target<cr>")

        keymap("n", "<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end, { desc = "Toggle inlay hints" })

        vim.lsp.config("roslyn", {
            on_attach = function()
                print("Roslyn Starting")
            end,
            settings = {
                ["csharp|quick_info"] = {
                    dotnet_show_remarks_in_quick_info = true,
                },
                ["csharp|inlay_hints"] = {
                    csharp_enable_inlay_hints_for_implicit_object_creation = true,
                    csharp_enable_inlay_hints_for_implicit_variable_types = true,
                    csharp_enable_inlay_hints_for_lambda_parameter_types = true,
                    csharp_enable_inlay_hints_for_types = true,
                    dotnet_enable_inlay_hints_for_indexer_parameters = true,
                    dotnet_enable_inlay_hints_for_literal_parameters = true,
                    dotnet_enable_inlay_hints_for_object_creation_parameters = true,
                    dotnet_enable_inlay_hints_for_other_parameters = true,
                    dotnet_enable_inlay_hints_for_parameters = true,
                    dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
                    dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
                    dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
                },
                ["csharp|code_lens"] = {
                    dotnet_enable_references_code_lens = true,
                },
                ["csharp|symbol_search"] = {
                    dotnet_search_reference_assemplies = true,
                },
                ["csharp|completion"] = {
                    dotnet_provide_regex_completions = true,
                    dotnet_show_completion_items_from_unimported_namespaces = true,
                    dotnet_show_name_completion_suggetions = true,
                },

            },
        })
    end,
}

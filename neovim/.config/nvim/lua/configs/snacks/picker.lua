local M = {}

M.Keys = {
    { "<leader><space>s", function() Snacks.picker.smart() end,                                   desc = "Smart Find Files" },
    { "<leader>,",        function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
    { "<leader>/",        function() Snacks.picker.grep() end,                                    desc = "Grep" },
    { "<leader>:",        function() Snacks.picker.command_history() end,                         desc = "Command History" },
    { "<leader>n",        function() Snacks.picker.notifications() end,                           desc = "Notification History" },
    { "<leader>e",        function() Snacks.explorer() end,                                       desc = "File Explorer" },
    -- find
    { "<leader>fb",       function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
    { "<leader>fc",       function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>ff",       function() Snacks.picker.files() end,                                   desc = "Find Files" },
    { "<leader>fp",       function() Snacks.picker.projects() end,                                desc = "Projects" },
    { "<leader>fr",       function() Snacks.picker.recent() end,                                  desc = "Recent" },
    -- git
    { "<leader>gff",      function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
    { "<leader>gbr",      function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
    { "<leader>glo",      function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
    { "<leader>gll",      function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
    { "<leader>gst",      function() Snacks.picker.git_status() end,                              desc = "Git Status" },
    { "<leader>gss",      function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
    { "<leader>gd",       function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
    { "<leader>gf",       function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
    -- Grep
    { "<leader>sb",       function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
    { "<leader>sbg",      function() Snacks.picker.grep_buffers() end,                            desc = "Grep Open Buffers" },
    { "<leader>fg",       function() Snacks.picker.grep() end,                                    desc = "Grep" },
    { "<leader>sw",       function() Snacks.picker.grep_word() end,                               desc = "Visual selection or word", mode = { "n", "x" } },
    -- search
    { '<leader>s"',       function() Snacks.picker.registers() end,                               desc = "Registers" },
    { '<leader>s/',       function() Snacks.picker.search_history() end,                          desc = "Search History" },
    { "<leader>sa",       function() Snacks.picker.autocmds() end,                                desc = "Autocmds" },
    { "<leader>sb",       function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
    { "<leader>sc",       function() Snacks.picker.command_history() end,                         desc = "Command History" },
    { "<leader>scc",      function() Snacks.picker.commands() end,                                desc = "Commands" },
    { "<leader>sd",       function() Snacks.picker.diagnostics() end,                             desc = "Diagnostics" },
    { "<leader>sds",      function() Snacks.picker.diagnostics_buffer() end,                      desc = "Buffer Diagnostics" },
    { "<leader>sh",       function() Snacks.picker.help() end,                                    desc = "Help Pages" },
    { "<leader>shs",      function() Snacks.picker.highlights() end,                              desc = "Highlights" },
    { "<leader>si",       function() Snacks.picker.icons() end,                                   desc = "Icons" },
    { "<leader>sj",       function() Snacks.picker.jumps() end,                                   desc = "Jumps" },
    { "<leader>sk",       function() Snacks.picker.keymaps() end,                                 desc = "Keymaps" },
    { "<leader>sl",       function() Snacks.picker.loclist() end,                                 desc = "Location List" },
    { "<leader>sm",       function() Snacks.picker.marks() end,                                   desc = "Marks" },
    { "<leader>sms",      function() Snacks.picker.man() end,                                     desc = "Man Pages" },
    { "<leader>sp",       function() Snacks.picker.lazy() end,                                    desc = "Search for Plugin Spec" },
    { "<leader>sq",       function() Snacks.picker.qflist() end,                                  desc = "Quickfix List" },
    { "<leader>srs",      function() Snacks.picker.resume() end,                                  desc = "Resume" },
    { "<leader>su",       function() Snacks.picker.undo() end,                                    desc = "Undo History" },
    { "<leader>scs",      function() Snacks.picker.colorschemes() end,                            desc = "Colorschemes" },
    -- LSP
    { "gd",               function() Snacks.picker.lsp_definitions() end,                         desc = "Goto Definition" },
    { "gtd",              function() Snacks.picker.lsp_declarations() end,                        desc = "Goto Declaration" },
    { "gr",               function() Snacks.picker.lsp_references() end,                          nowait = true,                     desc = "References" },
    { "gti",              function() Snacks.picker.lsp_implementations() end,                     desc = "Goto Implementation" },
    { "gy",               function() Snacks.picker.lsp_type_definitions() end,                    desc = "Goto T[y]pe Definition" },
    { "<leader>ss",       function() Snacks.picker.lsp_symbols() end,                             desc = "LSP Symbols" },
    { "<leader>sls",      function() Snacks.picker.lsp_workspace_symbols() end,                   desc = "LSP Workspace Symbols" },
    --scratch
    { "<leader>.",        function() Snacks.scratch() end,                                        desc = "Toggle Scratch Buffer" },
    { "<leader>S",        function() Snacks.scratch.select() end,                                 desc = "Select Scratch Buffer" },
    -- Other
    { "<leader>bd",       function() Snacks.bufdelete() end,                                      desc = "Delete Buffer" },
}

return M

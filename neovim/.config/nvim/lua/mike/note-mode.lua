-- ~/.config/nvim/lua/mike/note-mode.lua
-- Note Mode: Combines auto-center and auto-wrap for better note-taking experience
local M = {}

local state = {
    enabled = false,
    align_cmd = "zz", -- "zz" (center) or "zt" (top)
    wrap_column = 160, -- Default wrap column for auto-wrap
}

local function center()
    local view = vim.fn.winsaveview()
    local win_height = vim.api.nvim_win_get_height(0)
    local cursor_line = view.lnum

    local new_topline = cursor_line - math.floor(win_height / 2)
    view.topline = math.max(1, new_topline)

    vim.fn.winrestview(view)
end

function M.setup(opts)
    opts = opts or {}

    state.enabled = opts.enabled or false
    state.align_cmd = opts.align or "zz"
    state.wrap_column = opts.wrap_column or 160

    local group = vim.api.nvim_create_augroup("MikeNoteMode", { clear = true })

    -- Auto-center: Center cursor while typing in insert mode
    vim.api.nvim_create_autocmd("CursorMovedI", {
        group = group,
        callback = center,
    })

    -- Auto-wrap: Wrap at first space after wrap_column when taking notes in markdown
    vim.api.nvim_create_autocmd("InsertCharPre", {
        group = group,
        pattern = { "*.md", "*.markdown" },
        desc = "Auto-wrap at first space after wrap column in markdown (Note Mode)",
        callback = function()
            if not state.enabled then return end

            -- Check if the character being inserted is a space
            if vim.v.char == ' ' then
                local line = vim.api.nvim_get_current_line()
                local line_len = #line

                -- Get wrap column: respect buffer textwidth, then config, then default
                local wrap_col = vim.bo.textwidth > 0 and vim.bo.textwidth or state.wrap_column

                -- Wrap at first space after the wrap column threshold
                if line_len >= wrap_col then
                    -- Cancel the space insertion
                    vim.v.char = ''

                    -- Get current indentation
                    local indent = line:match("^%s*")

                    -- Schedule the newline and indentation insertion
                    vim.schedule(function()
                        -- Insert newline and preserved indentation
                        vim.api.nvim_put({ '', indent }, 'c', true, true)
                    end)
                end
            end
        end,
    })

    -- Commands
    vim.api.nvim_create_user_command("NoteModeToggle", function()
        state.enabled = not state.enabled
        vim.notify("Note Mode: " .. (state.enabled and "ON" or "OFF"))
    end, { desc = "Toggle Note Mode" })

    vim.api.nvim_create_user_command("NoteModeOn", function()
        state.enabled = true
        vim.notify("Note Mode: ON")
    end, { desc = "Enable Note Mode" })

    vim.api.nvim_create_user_command("NoteModeOff", function()
        state.enabled = false
        vim.notify("Note Mode: OFF")
    end, { desc = "Disable Note Mode" })

    -- Optional keymap
    if opts.map ~= false then
        vim.keymap.set(
            "n",
            opts.keymap or "<leader>uz",
            "<cmd>NoteModeToggle<cr>",
            { desc = "Toggle Note Mode (auto-center + auto-wrap)" }
        )
    end
end

return M

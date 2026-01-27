-- Outstanding Questions - Collect and manage outstanding questions in markdown
-- Parses markdown blockquote callouts with [!IMPORTANT] Outstanding header
-- and displays questions in a Snacks picker with toggle functionality

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local DEFAULT_CONFIG = {
    -- Lua pattern to match the header line (case-insensitive for "Outstanding")
    header_pattern = "^>%s*%[!IMPORTANT%]%s*[Oo]utstanding",

    -- Display icons in picker
    icons = {
        resolved = "✓",
        open = "○",
    },
}

local config = vim.deepcopy(DEFAULT_CONFIG)

-- ============================================================================
-- PARSER
-- ============================================================================

--- Parse the current buffer for outstanding questions
--- Finds all [!IMPORTANT] Outstanding blocks and extracts questions
---@param bufnr number Buffer number to parse
---@return table[] List of questions: {text, resolved, lnum, bufnr}
local function parse_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local questions = {}

    local in_block = false

    for lnum, line in ipairs(lines) do
        -- Check for header line
        if line:match(config.header_pattern) then
            in_block = true
        elseif in_block then
            -- Check if still in blockquote
            if line:match("^>") then
                -- Skip empty blockquote lines
                if not line:match("^>%s*$") then
                    -- Check for resolved marker: > - [x] text
                    local resolved_text = line:match("^>%s*-%s*%[x%]%s*(.+)$")
                    if resolved_text then
                        table.insert(questions, {
                            text = resolved_text,
                            resolved = true,
                            lnum = lnum,
                            bufnr = bufnr,
                        })
                    else
                        -- Unresolved: > text (but not header or empty)
                        local text = line:match("^>%s*(.+)$")
                        if text and not text:match("^%[!") then
                            table.insert(questions, {
                                text = text,
                                resolved = false,
                                lnum = lnum,
                                bufnr = bufnr,
                            })
                        end
                    end
                end
            else
                -- Line doesn't start with >, end of block
                in_block = false
            end
        end
    end

    return questions
end

-- ============================================================================
-- BUFFER MODIFICATION
-- ============================================================================

--- Toggle the resolved state of a question at a specific line
---@param bufnr number Buffer number
---@param lnum number Line number (1-indexed)
local function toggle_resolved(bufnr, lnum)
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    if not line then return end

    local new_line

    -- Check if already resolved: > - [x] text
    local prefix, text = line:match("^(>%s*)-%s*%[x%]%s*(.+)$")
    if prefix and text then
        -- Remove - [x] marker
        new_line = prefix .. text
    else
        -- Add - [x] marker: > text -> > - [x] text
        prefix, text = line:match("^(>%s*)(.+)$")
        if prefix and text then
            new_line = prefix .. "- [x] " .. text
        end
    end

    if new_line then
        vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
    end
end

-- ============================================================================
-- PICKER FORMATTING
-- ============================================================================

--- Format an item for display in the picker
---@param item table Question item
---@return string Formatted display string
local function format_item(item)
    local icon = item.resolved and config.icons.resolved or config.icons.open
    return string.format("%s %s", icon, item.text)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Open the Snacks picker with outstanding questions from current buffer
function M.open_picker()
    local bufnr = vim.api.nvim_get_current_buf()
    local questions = parse_buffer(bufnr)

    if #questions == 0 then
        vim.notify("No outstanding questions found in buffer", vim.log.levels.INFO)
        return
    end

    -- Build items for picker
    local items = {}
    for _, q in ipairs(questions) do
        table.insert(items, {
            text = format_item(q),
            label = q.text,
            resolved = q.resolved,
            lnum = q.lnum,
            bufnr = q.bufnr,
            file = vim.api.nvim_buf_get_name(bufnr),
            pos = { q.lnum, 0 },
        })
    end

    Snacks.picker.pick({
        source = "outstanding",
        title = "Outstanding Questions",
        items = items,
        format = function(item, _)
            local ret = {}
            local icon = item.resolved and config.icons.resolved or config.icons.open
            local hl = item.resolved and "Comment" or "Normal"
            table.insert(ret, { icon .. " ", hl })
            table.insert(ret, { item.label, hl })
            return ret
        end,
        confirm = function(picker, item)
            if item then
                picker:close()
                vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
                vim.cmd("normal! zz")
            end
        end,
        actions = {
            toggle = function(picker)
                local item = picker:current()
                if item then
                    toggle_resolved(item.bufnr, item.lnum)
                    -- Refresh picker with updated data
                    local new_questions = parse_buffer(item.bufnr)
                    local new_items = {}
                    for _, q in ipairs(new_questions) do
                        table.insert(new_items, {
                            text = format_item(q),
                            label = q.text,
                            resolved = q.resolved,
                            lnum = q.lnum,
                            bufnr = q.bufnr,
                            file = vim.api.nvim_buf_get_name(item.bufnr),
                            pos = { q.lnum, 0 },
                        })
                    end
                    picker.opts.items = new_items
                    picker:find()
                end
            end,
        },
        win = {
            input = {
                keys = {
                    ["<Tab>"] = { "toggle", mode = { "n", "i" }, desc = "Toggle resolved" },
                },
            },
            list = {
                keys = {
                    ["<Tab>"] = { "toggle", mode = { "n" }, desc = "Toggle resolved" },
                },
            },
        },
    })
end

--- Toggle resolved state at cursor position (for inline use)
function M.toggle_at_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]

    -- Verify cursor is on a blockquote line
    if not line or not line:match("^>") then
        vim.notify("Cursor is not on a blockquote line", vim.log.levels.WARN)
        return
    end

    toggle_resolved(bufnr, lnum)
end

-- ============================================================================
-- SETUP
-- ============================================================================

--- Setup the outstanding questions module
---@param opts table|nil Configuration options
function M.setup(opts)
    config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts or {})

    -- Create commands only for markdown buffers
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("OutstandingQuestions", { clear = true }),
        pattern = { "markdown" },
        callback = function(ev)
            -- Buffer-local commands
            vim.api.nvim_buf_create_user_command(ev.buf, "OutstandingQuestions", function()
                M.open_picker()
            end, { desc = "Open outstanding questions picker" })

            vim.api.nvim_buf_create_user_command(ev.buf, "OutstandingToggle", function()
                M.toggle_at_cursor()
            end, { desc = "Toggle resolved state at cursor" })
        end,
    })
end

-- ============================================================================
-- LAZY.NVIM PLUGIN SPEC
-- ============================================================================

return {
    name = "outstanding",
    dir = vim.fn.stdpath("config") .. "/lua/configs",
    dependencies = { "folke/snacks.nvim" },
    ft = { "markdown" },
    keys = {
        {
            "<leader>mo",
            function() M.open_picker() end,
            desc = "Outstanding Questions",
            ft = "markdown",
        },
        {
            "<leader>mt",
            function() M.toggle_at_cursor() end,
            desc = "Toggle Outstanding",
            ft = "markdown",
        },
    },
    opts = {},
    config = function(_, opts)
        M.setup(opts)
    end,
}

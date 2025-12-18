-- Git AutoCommit Plugin Implementation

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local DEFAULT_CONFIG = {
    -- AI Settings
    model = "qwen2.5-coder:7b",
    ollama_api_url = "http://localhost:11434/api/generate",
    ollama_timeout = 60000,  -- ms
    temperature = 0.7,
    max_tokens = 200,
    stream_response = true,  -- Enable streaming by default

    -- Retry Settings
    max_attempts = 5,
    max_api_retries = 3,
    retry_delay = 1000,      -- Base delay in ms
    max_retry_delay = 5000,  -- Cap for exponential backoff

    -- Commit Message Settings
    commit_style = "plain",  -- "plain" | "conventional" | "angular" | "gitmoji" | "custom"
    conventional_types = {   -- For conventional commits
        "feat", "fix", "docs", "style", "refactor",
        "perf", "test", "build", "ci", "chore", "revert"
    },
    commit_subject_max_length = 50,
    commit_body_wrap_length = 72,
    custom_prompt_template = nil,  -- Optional: override default prompt

    -- Git Settings
    max_diff_lines = 500,
    max_context_chars = 8000,

    -- UI Settings
    show_progress = true,
    fallback_message_prefix = "Auto-commit",
    window_config = {
        border = "rounded",
        title_pos = "center",
    },
}

local config = vim.deepcopy(DEFAULT_CONFIG)

-- ============================================================================
-- SPINNER CONFIGURATION
-- ============================================================================
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local SPINNER_ID = "git_autocommit_spinner"

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================
local State = {}
State.__index = State

function State:new()
    return setmetatable({
        attempt = 0,
        diff = nil,
        user_guidance = nil,
        windows = {},
        buffers = {},
        temp_files = {},
        active = false,
        commit_message_buf = nil,
        captured_message = nil,  -- Store edited message before prompt
        spinner_timer = nil,
        spinner_frame = 1,
    }, self)
end

function State:add_window(win)
    table.insert(self.windows, win)
end

function State:add_buffer(buf)
    table.insert(self.buffers, buf)
end

function State:add_temp_file(file)
    table.insert(self.temp_files, file)
end

function State:cleanup()
    -- Stop spinner first
    stop_spinner()
    
    for _, win in ipairs(self.windows) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end

    for _, buf in ipairs(self.buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    for _, file in ipairs(self.temp_files) do
        pcall(vim.fn.delete, file)
    end

    self.windows = {}
    self.buffers = {}
    self.temp_files = {}
    self.commit_message_buf = nil
    self.captured_message = nil
end

function State:reset()
    self:cleanup()
    self.attempt = 0
    self.diff = nil
    self.user_guidance = nil
    self.active = false
end

function State:cleanup_ui_only()
    -- Clean UI but preserve attempt, diff, guidance for regeneration
    for _, win in ipairs(self.windows) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end

    for _, buf in ipairs(self.buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    self.windows = {}
    self.buffers = {}
    self.commit_message_buf = nil
    self.captured_message = nil
    -- Preserve: attempt, diff, user_guidance, active, temp_files
end

local state = State:new()

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- ============================================================================
-- SPINNER FUNCTIONS
-- ============================================================================

local function start_spinner(message)
    if not config.show_progress then
        return
    end

    -- Stop any existing spinner
    stop_spinner()

    -- Reset frame counter
    state.spinner_frame = 1

    -- Create timer to update spinner every 80ms
    state.spinner_timer = vim.uv.new_timer()
    state.spinner_timer:start(
        0,
        80,
        vim.schedule_wrap(function()
            -- Update the notification with current spinner frame
            vim.notify(message, vim.log.levels.INFO, {
                id = SPINNER_ID,
                title = "Git AutoCommit",
                icon = SPINNER_FRAMES[state.spinner_frame],
                timeout = false, -- Keep notification visible until manually dismissed
            })

            -- Move to next frame
            state.spinner_frame = state.spinner_frame + 1
            if state.spinner_frame > #SPINNER_FRAMES then
                state.spinner_frame = 1
            end
        end)
    )
end

function stop_spinner()
    if state.spinner_timer then
        state.spinner_timer:stop()
        state.spinner_timer:close()
        state.spinner_timer = nil
    end

    -- Hide the notification
    local ok, snacks = pcall(require, "snacks")
    if ok and snacks.notifier then
        snacks.notifier.hide(SPINNER_ID)
    end
end

-- Word-wrapping that respects boundaries
local function wrap_text(text, width)
    local lines = {}

    for paragraph in text:gmatch("([^\n]*)\n?") do
        if paragraph ~= "" then
            local line = ""
            for word in paragraph:gmatch("%S+") do
                -- Handle very long words (URLs, paths)
                if #word > width then
                    if #line > 0 then
                        table.insert(lines, line)
                        line = ""
                    end
                    -- Break long word into chunks
                    for i = 1, #word, width do
                        table.insert(lines, word:sub(i, i + width - 1))
                    end
                elseif #line == 0 then
                    line = word
                elseif #line + #word + 1 <= width then
                    line = line .. " " .. word
                else
                    table.insert(lines, line)
                    line = word
                end
            end
            if #line > 0 then
                table.insert(lines, line)
            end
        else
            table.insert(lines, "")
        end
    end

    return lines
end

-- Escape triple backticks in diff to prevent prompt injection
local function escape_code_fences(text)
    -- Count existing backticks to determine safe fence length
    local max_backticks = 3
    for backticks in text:gmatch("`+") do
        max_backticks = math.max(max_backticks, #backticks + 1)
    end
    return string.rep("`", max_backticks), text
end

-- ============================================================================
-- PREREQUISITES & VALIDATION
-- ============================================================================

local function is_git_repo()
    local result = vim.fn.system("git rev-parse --git-dir 2>&1")
    return vim.v.shell_error == 0
end

local function has_staged_changes()
    vim.fn.system("git diff --cached --quiet")
    return vim.v.shell_error ~= 0
end

local function check_ollama_sync()
    local base_url = config.ollama_api_url:gsub("/api/generate$", "")
    local result = vim.fn.system(string.format('curl -s --max-time 2 %s/api/tags', base_url))
    return vim.v.shell_error == 0, result
end

local function check_ollama_async(callback)
    local base_url = config.ollama_api_url:gsub("/api/generate$", "")

    vim.system(
        { 'curl', '-s', '--max-time', '3', base_url .. '/api/tags' },
        { text = true },
        vim.schedule_wrap(function(result)
            callback(result.code == 0, result.stderr or "")
        end)
    )
end

local function check_prerequisites(callback)
    if not is_git_repo() then
        return callback(false, "Not a git repository")
    end

    if not has_staged_changes() then
        return callback(false, "No staged changes to commit")
    end

    if state.active then
        return callback(false, "Git autocommit is already running")
    end

    -- Async Ollama check
    check_ollama_async(function(ollama_success)
        if not ollama_success then
            vim.schedule(function()
                vim.notify(
                    "Ollama not responding - fallback will be available",
                    vim.log.levels.WARN
                )
            end)
        end
        callback(true)
    end)
end

-- ============================================================================
-- GIT OPERATIONS
-- ============================================================================

local function get_staged_diff(callback)
    vim.system(
        { 'git', 'diff', '--cached' },
        { text = true },
        vim.schedule_wrap(function(result)
            if result.code == 0 then
                callback(true, result.stdout)
            else
                callback(false, "Failed to get git diff")
            end
        end)
    )
end

local function truncate_diff(diff, callback)
    local lines = vim.split(diff, '\n')
    local line_count = #lines
    local char_count = #diff

    if line_count <= config.max_diff_lines and char_count <= config.max_context_chars then
        return callback(diff)
    end

    vim.notify(
        string.format("Large diff (%d lines, %d chars) - truncating for AI", line_count, char_count),
        vim.log.levels.INFO
    )

    vim.system(
        { 'git', 'diff', '--cached', '--stat' },
        { text = true },
        vim.schedule_wrap(function(result)
            local stats = result.stdout or ""
            local truncated_lines = {}

            for i = 1, math.min(100, line_count) do
                table.insert(truncated_lines, lines[i])
            end

            local truncated = stats .. "\n\n" ..
                table.concat(truncated_lines, "\n") ..
                "\n\n... (diff truncated for AI context)"

            callback(truncated)
        end)
    )
end

local function execute_commit(message, callback)
    local tempfile = vim.fn.tempname()
    state:add_temp_file(tempfile)

    -- Write with restricted permissions
    vim.fn.writefile(vim.split(message, '\n'), tempfile)
    vim.fn.setfperm(tempfile, "rw-------")

    vim.system(
        { 'git', 'commit', '-F', tempfile },
        { text = true },
        vim.schedule_wrap(function(result)
            if result.code == 0 then
                callback(true, "Commit created successfully")
            else
                callback(false, "Commit failed: " .. (result.stderr or "unknown error"))
            end
        end)
    )
end

-- ============================================================================
-- AI INTEGRATION - PROMPT BUILDING
-- ============================================================================

local function build_prompt(diff, user_guidance)
    local fence, escaped_diff = escape_code_fences(diff)

    -- Custom template override
    if config.custom_prompt_template then
        return config.custom_prompt_template
            :gsub("{{diff}}", escaped_diff)
            :gsub("{{guidance}}", user_guidance or "")
            :gsub("{{fence}}", fence)
    end

    -- Build style-specific instructions
    local style_instructions = ""

    if config.commit_style == "conventional" or config.commit_style == "angular" then
        local types = table.concat(config.conventional_types, ", ")
        style_instructions = string.format([[
CONVENTIONAL COMMIT FORMAT:
- First line: <type>(<scope>): <description>
  - type: one of [%s]
  - scope: optional, area affected (e.g., api, ui, auth)
  - description: imperative, lowercase, no period
- Blank line
- Body: Detailed explanation wrapped at %d chars
- Optional footer: Breaking changes, issue references

Example:
feat(auth): add OAuth2 authentication

Implement OAuth2 flow with Google and GitHub providers.
Includes token refresh and secure storage.

Closes #123
]], types, config.commit_body_wrap_length)
    elseif config.commit_style == "gitmoji" then
        style_instructions = string.format([[
GITMOJI COMMIT FORMAT:
- Start with relevant emoji (e.g., ✨ new feature, 🐛 bug fix, 📝 docs)
- Follow with imperative description
- Subject line: %d characters max
- Blank line
- Body: Detailed explanation wrapped at %d chars
]], config.commit_subject_max_length, config.commit_body_wrap_length)
    else  -- plain
        style_instructions = string.format([[
PLAIN COMMIT FORMAT:
- First line: %d characters or less (imperative, descriptive)
- Blank line
- Body: Detailed explanation wrapped at %d chars
- Focus on what changed and why
- Use plain language, no special prefixes
]], config.commit_subject_max_length, config.commit_body_wrap_length)
    end

    local prompt = string.format([[You are generating a git commit message. Analyze the diff and create a detailed, descriptive commit message.

%s

STYLE GUIDELINES:
- Be descriptive and specific
- Write in imperative mood (e.g., "Add feature" not "Added feature")
- Focus on what changed and the purpose/motivation
- Keep subject line concise, body detailed

DIFF:
%s%s
%s]], style_instructions, fence, escaped_diff, fence)

    if user_guidance and user_guidance ~= "" then
        prompt = prompt .. "\n\nUSER GUIDANCE: " .. user_guidance
    end

    prompt = prompt .. "\n\nGenerate only the commit message, nothing else."

    return prompt
end

-- ============================================================================
-- AI INTEGRATION - STREAMING PARSER (ROBUST)
-- ============================================================================

local StreamingParser = {}
StreamingParser.__index = StreamingParser

function StreamingParser:new()
    return setmetatable({
        buffer = "",
        full_response = "",
        parse_errors = 0,
        max_parse_errors = 3,
    }, self)
end

-- Line-buffered parsing: safer than brace-matching
function StreamingParser:add_chunk(chunk)
    self.buffer = self.buffer .. chunk

    -- Process complete lines (ending with \n)
    while true do
        local newline_pos = self.buffer:find("\n")
        if not newline_pos then break end

        local line = self.buffer:sub(1, newline_pos - 1)
        self.buffer = self.buffer:sub(newline_pos + 1)

        -- Try to parse JSON line
        if line ~= "" and line:match("^%s*{") then
            local ok, json = pcall(vim.json.decode, line)
            if ok and json.response then
                self.full_response = self.full_response .. json.response
            elseif not ok then
                self.parse_errors = self.parse_errors + 1
                if self.parse_errors >= self.max_parse_errors then
                    return false, "Too many JSON parse errors in stream"
                end
            end

            -- Check for done signal
            if ok and json.done then
                return true, self.full_response
            end
        end
    end

    return nil, nil  -- Not done yet, keep reading
end

function StreamingParser:get_result()
    return self.full_response
end

-- ============================================================================
-- AI INTEGRATION - API CALL
-- ============================================================================

local function call_ollama_with_retry(prompt, attempt, callback)
    attempt = attempt or 1

    if attempt > config.max_api_retries then
        return callback(false, "AI service not responding after " .. config.max_api_retries .. " attempts")
    end

    if attempt > 1 then
        vim.schedule(function()
            vim.notify(
                string.format("Retrying AI request (%d/%d)...", attempt, config.max_api_retries),
                vim.log.levels.INFO
            )
        end)
    end

    -- Build payload
    local payload = vim.json.encode({
        model = config.model,
        prompt = prompt,
        stream = config.stream_response,
        options = {
            temperature = config.temperature,
            num_predict = config.max_tokens,
        }
    })

    -- Write payload to temp file with restricted permissions
    local payload_file = vim.fn.tempname()
    state:add_temp_file(payload_file)
    vim.fn.writefile({ payload }, payload_file)
    vim.fn.setfperm(payload_file, "rw-------")

    local timeout_seconds = tostring(math.floor(config.ollama_timeout / 1000))

    -- Use vim.system for async execution
    local stdout_data = ""
    local parser = config.stream_response and StreamingParser:new() or nil

    vim.system(
        {
            'curl', '-s', '-N',  -- -N for no buffering (streaming)
            '--max-time', timeout_seconds,
            config.ollama_api_url,
            '-H', 'Content-Type: application/json',
            '-d', '@' .. payload_file
        },
        {
            text = true,
            stdout = function(_, data)
                if data then
                    stdout_data = stdout_data .. data

                    -- For streaming, process incrementally
                    if parser then
                        local done, result_or_err = parser:add_chunk(data)
                        if done == false then
                            -- Parse error, abort
                            vim.schedule(function()
                                vim.notify("Streaming parse error, retrying without streaming...", vim.log.levels.WARN)
                            end)
                            -- Retry with streaming disabled
                            config.stream_response = false
                            local delay = math.min(config.retry_delay * attempt, config.max_retry_delay)
                            vim.defer_fn(function()
                                call_ollama_with_retry(prompt, attempt + 1, callback)
                            end, delay)
                        end
                    end
                end
            end
        },
        vim.schedule_wrap(function(result)
            -- Check curl exit code
            if result.code ~= 0 then
                -- Exponential backoff with cap
                if attempt < config.max_api_retries then
                    local delay = math.min(config.retry_delay * attempt, config.max_retry_delay)
                    vim.defer_fn(function()
                        call_ollama_with_retry(prompt, attempt + 1, callback)
                    end, delay)
                else
                    callback(false, "Unable to connect to Ollama. Is it running?")
                end
                return
            end

            -- Parse response
            local message
            if config.stream_response and parser then
                message = parser:get_result()
            else
                local ok, response = pcall(vim.json.decode, stdout_data)
                if not ok then
                    return callback(false, "Invalid JSON response from Ollama")
                end
                message = response.response
            end

            if not message or message == "" then
                return callback(false, "Empty response from AI")
            end

            callback(true, message)
        end)
    )
end

-- ============================================================================
-- AI INTEGRATION - FORMATTING
-- ============================================================================

local function format_commit_message(message)
    -- Remove markdown code blocks (handle various fence styles)
    message = message:gsub("```[%w%-%.%+]*\n?", "")
    message = message:gsub("^%s+", ""):gsub("%s+$", "")

    local lines = vim.split(message, '\n')

    -- Validate subject line length
    if #lines > 0 then
        local subject = lines[1]
        if #subject > config.commit_subject_max_length then
            lines[1] = subject:sub(1, config.commit_subject_max_length - 3) .. "..."
        end
    end

    -- Wrap body lines
    if #lines > 2 then
        local wrapped_body = {}
        for i = 3, #lines do
            local wrapped_lines = wrap_text(lines[i], config.commit_body_wrap_length)
            for _, wrapped_line in ipairs(wrapped_lines) do
                table.insert(wrapped_body, wrapped_line)
            end
        end

        local new_lines = { lines[1] }
        if lines[2] then
            table.insert(new_lines, lines[2])
        end
        for _, line in ipairs(wrapped_body) do
            table.insert(new_lines, line)
        end
        lines = new_lines
    end

    return table.concat(lines, '\n')
end

local function generate_fallback_message()
    return config.fallback_message_prefix .. ": " .. os.date("%Y-%m-%d %H:%M:%S")
end

-- ============================================================================
-- UI COMPONENTS
-- ============================================================================

local function create_float_window(message, attempt)
    local lines = vim.split(message, '\n')
    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, #line)
    end
    width = math.min(width + 4, vim.o.columns - 10)
    local height = math.min(#lines + 6, vim.o.lines - 10)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.bo[buf].filetype = 'gitcommit'
    vim.bo[buf].modifiable = true
    vim.bo[buf].bufhidden = 'wipe'

    local opts = vim.tbl_extend("force", {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        title = string.format(
            " Generated Commit Message (%d/%d) ",
            attempt,
            config.max_attempts
        ),
    }, config.window_config)

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.wo[win].cursorline = true
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true

    -- Add instructions at bottom
    local ns = vim.api.nvim_create_namespace('git_autocommit_help')
    vim.api.nvim_buf_set_extmark(buf, ns, #lines, 0, {
        virt_lines = {
            { { "" } },
            { { "Edit as needed, then close this window to continue", "Comment" } },
            { { "Press 'q' or <Esc> to close", "Comment" } },
        },
        virt_lines_above = false,
    })

    -- Keymaps
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local opts_local = { silent = true, buffer = buf }
    vim.keymap.set('n', 'q', close_window, opts_local)
    vim.keymap.set('n', '<Esc>', close_window, opts_local)

    state:add_buffer(buf)
    state:add_window(win)
    state.commit_message_buf = buf

    return buf, win
end

local function prompt_user_action(callback)
    vim.ui.select(
        { 'Accept and commit', 'Cancel', 'Provide guidance and regenerate' },
        {
            prompt = 'Choose action:',
            format_item = function(item) return item end,
        },
        function(choice, idx)
            if not choice then
                callback('cancel')
            elseif idx == 1 then
                callback('accept')
            elseif idx == 2 then
                callback('cancel')
            elseif idx == 3 then
                callback('guidance')
            end
        end
    )
end

local function get_user_guidance(callback)
    vim.ui.input(
        { prompt = 'Provide guidance for regeneration: ' },
        function(input)
            callback(input)
        end
    )
end

-- ============================================================================
-- MAIN WORKFLOW (ITERATIVE, NOT RECURSIVE)
-- ============================================================================

local function run_workflow()
    -- Iterative loop to avoid stack buildup
    state.attempt = state.attempt + 1

    -- Generate message
    local prompt = build_prompt(state.diff, state.user_guidance)

    -- Start spinner before AI generation
    start_spinner("Generating commit message...")

    -- Make this synchronous via coroutine or nested callback
    -- For simplicity in plan, using callback pattern
    call_ollama_with_retry(prompt, 1, function(success, result)
        if not success then
            -- Stop spinner on error
            stop_spinner()
            
            -- AI failed, offer fallback
            vim.schedule(function()
                vim.notify("AI generation failed: " .. result, vim.log.levels.WARN)

                local fallback = generate_fallback_message()
                vim.ui.select(
                    { 'Use fallback message', 'Cancel' },
                    { prompt = 'Fallback: ' .. fallback },
                    function(choice, idx)
                        if idx == 1 then
                            execute_commit(fallback, function(ok, msg)
                                state:reset()
                                vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
                            end)
                        else
                            state:reset()
                            vim.notify("Commit cancelled", vim.log.levels.INFO)
                        end
                    end
                )
            end)
            return  -- Exit workflow
        end

        -- Stop spinner on success
        stop_spinner()

        -- Format message
        local formatted_message = format_commit_message(result)

        -- Display in floating window
        vim.schedule(function()
            local buf, win = create_float_window(formatted_message, state.attempt)

            -- Wait for user to close window
            vim.api.nvim_create_autocmd("WinClosed", {
                pattern = tostring(win),
                once = true,
                callback = function()
                    -- Capture edited message BEFORE prompting
                    if vim.api.nvim_buf_is_valid(buf) then
                        local edited_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                        state.captured_message = table.concat(edited_lines, '\n')
                    else
                        state.captured_message = formatted_message
                    end

                    -- Now prompt for action
                    prompt_user_action(function(action)
                        if action == 'accept' then
                            execute_commit(state.captured_message, function(ok, msg)
                                state:reset()
                                vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
                            end)
                        elseif action == 'cancel' then
                            state:reset()
                            vim.notify("Commit cancelled", vim.log.levels.INFO)
                        elseif action == 'guidance' then
                            get_user_guidance(function(guidance)
                                if guidance and guidance ~= "" then
                                    state.user_guidance = guidance
                                    state:cleanup_ui_only()

                                    if state.attempt >= config.max_attempts then
                                        vim.notify("Maximum attempts reached", vim.log.levels.WARN)
                                        local fallback = generate_fallback_message()
                                        vim.ui.select(
                                            { 'Use fallback message', 'Cancel' },
                                            { prompt = 'Fallback: ' .. fallback },
                                            function(choice, idx)
                                                if idx == 1 then
                                                    execute_commit(fallback, function(ok, msg)
                                                        state:reset()
                                                        vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
                                                    end)
                                                else
                                                    state:reset()
                                                    vim.notify("Commit cancelled", vim.log.levels.INFO)
                                                end
                                            end
                                        )
                                    else
                                        -- Continue loop by calling run_workflow recursively
                                        -- (Note: This is still recursive but unavoidable with async)
                                        run_workflow()
                                    end
                                else
                                    state:reset()
                                    vim.notify("Commit cancelled", vim.log.levels.INFO)
                                end
                            end)
                        end
                    end)
                end,
            })
        end)
    end)
end

-- ============================================================================
-- ENTRY POINTS
-- ============================================================================

function M.run()
    state:reset()
    state.active = false

    check_prerequisites(function(success, err)
        if not success then
            state.active = false
            vim.schedule(function()
                vim.notify(err, vim.log.levels.ERROR)
            end)
            return
        end

        get_staged_diff(function(success_result, diff)
            if not success_result then
                state.active = false
                vim.schedule(function()
                    vim.notify(diff, vim.log.levels.ERROR)
                end)
                return
            end

            if diff == "" then
                state.active = false
                vim.schedule(function()
                    vim.notify("No diff to analyze", vim.log.levels.ERROR)
                end)
                return
            end

            truncate_diff(diff, function(truncated)
                state.diff = truncated
                run_workflow()
            end)
        end)
    end)
end

-- ============================================================================
-- HEALTH CHECK
-- ============================================================================

function M.health()
    local health = vim.health or require("health")

    health.start("git-autocommit")

    -- Neovim version
    if vim.fn.has('nvim-0.10') == 1 then
        health.ok("Neovim 0.10+ detected")
    else
        health.error("Neovim 0.10+ required")
    end

    -- Git
    if is_git_repo() then
        health.ok("Git repository detected")
        if has_staged_changes() then
            health.ok("Staged changes found")
        else
            health.info("No staged changes")
        end
    else
        health.error("Not in a git repository")
    end

    -- Ollama
    health.start("Ollama Integration")
    health.info("API URL: " .. config.ollama_api_url)

    local success, result = check_ollama_sync()
    if success then
        health.ok("Ollama API responding")

        -- Parse tags to check if model exists
        local ok, data = pcall(vim.json.decode, result)
        if ok and data.models then
            local found = false
            for _, model in ipairs(data.models) do
                if model.name == config.model or model.name:match("^" .. config.model) then
                    found = true
                    break
                end
            end
            if found then
                health.ok("Model '" .. config.model .. "' is available")
            else
                health.warn("Model '" .. config.model .. "' not found in Ollama")
            end
        else
            health.warn("Could not verify model availability")
        end
    else
        health.warn("Ollama not responding - fallback messages will be used")
    end

    -- Curl
    if vim.fn.executable('curl') == 1 then
        health.ok("curl found")
    else
        health.error("curl not found (required for Ollama API)")
    end

    -- Config
    health.start("Configuration")
    health.info("Model: " .. config.model)
    health.info("Commit style: " .. config.commit_style)
    health.info("Streaming: " .. tostring(config.stream_response))
    health.info("Max attempts: " .. config.max_attempts)
    health.info("Temperature: " .. config.temperature)

    if config.temperature > 1.0 then
        health.warn("Temperature > 1.0 may produce unpredictable results")
    end
    if config.max_tokens < 50 then
        health.warn("max_tokens might be too low for good commit messages")
    end
end

-- ============================================================================
-- SETUP & COMMANDS
-- ============================================================================

function M.setup(opts)
    -- Validate configuration
    if opts then
        vim.validate({
            model = { opts.model, 'string', true },
            commit_style = { opts.commit_style, function(v)
                return v == nil or vim.tbl_contains(
                    { 'plain', 'conventional', 'angular', 'gitmoji', 'custom' },
                    v
                )
            end, "one of: plain, conventional, angular, gitmoji, custom" },
            max_attempts = { opts.max_attempts, function(v)
                return v == nil or (type(v) == 'number' and v > 0 and v <= 10)
            end, "positive number <= 10" },
            max_api_retries = { opts.max_api_retries, 'number', true },
            temperature = { opts.temperature, function(v)
                return v == nil or (type(v) == 'number' and v >= 0 and v <= 2)
            end, "number between 0 and 2" },
            max_tokens = { opts.max_tokens, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            max_diff_lines = { opts.max_diff_lines, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            max_context_chars = { opts.max_context_chars, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            commit_subject_max_length = { opts.commit_subject_max_length, function(v)
                return v == nil or (type(v) == 'number' and v > 0 and v <= 100)
            end, "positive number <= 100" },
            commit_body_wrap_length = { opts.commit_body_wrap_length, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            retry_delay = { opts.retry_delay, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            max_retry_delay = { opts.max_retry_delay, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
            ollama_timeout = { opts.ollama_timeout, function(v)
                return v == nil or (type(v) == 'number' and v > 0)
            end, "positive number" },
        })
    end

    config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts or {})

    -- User commands
    vim.api.nvim_create_user_command("GitAutoCommit", function()
        M.run()
    end, { desc = "Generate AI-powered commit message" })

    vim.api.nvim_create_user_command("GitAutoCommitHealth", function()
        M.health()
    end, { desc = "Check plugin health" })

    vim.api.nvim_create_user_command("GitAutoCommitModel", function(cmd_opts)
        config.model = cmd_opts.args
        vim.notify("Model set to: " .. config.model, vim.log.levels.INFO)
    end, {
        nargs = 1,
        desc = "Set Ollama model",
        complete = function()
            return { 'qwen2.5-coder:7b', 'llama3.2', 'codellama', 'deepseek-coder-v2' }
        end
    })

    vim.api.nvim_create_user_command("GitAutoCommitStyle", function(cmd_opts)
        config.commit_style = cmd_opts.args
        vim.notify("Commit style set to: " .. config.commit_style, vim.log.levels.INFO)
    end, {
        nargs = 1,
        desc = "Set commit message style",
        complete = function()
            return { 'plain', 'conventional', 'angular', 'gitmoji' }
        end
    })

    vim.api.nvim_create_user_command("GitAutoCommitConfig", function()
        vim.notify(vim.inspect(config), vim.log.levels.INFO)
    end, { desc = "Show current configuration" })

    -- Cleanup on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("GitAutoCommitCleanup", { clear = true }),
        callback = function()
            if state.active then
                state:cleanup()
            end
        end,
    })
end

-- ============================================================================
-- PLUGIN SPEC FOR LAZY.NVIM
-- ============================================================================

return {
    name = "git-autocommit",
    dir = vim.fn.stdpath("config") .. "/lua/configs",
    lazy = false,
    keys = {
        { "<leader>gac", "<cmd>GitAutoCommit<cr>", desc = "Git Auto Commit" },
        { "<leader>gah", "<cmd>GitAutoCommitHealth<cr>", desc = "Git Auto Commit Health" },
        { "<leader>gam", ":GitAutoCommitModel ", desc = "Set Model" },
        { "<leader>gas", ":GitAutoCommitStyle ", desc = "Set Style" },
        { "<leader>gai", "<cmd>GitAutoCommitConfig<cr>", desc = "Show Config" },
    },
    opts = {
        model = "qwen2.5-coder:7b",
        commit_style = "conventional",
        temperature = 0.7,
        max_attempts = 5,
        stream_response = true,
    },
    config = function(_, opts)
        M.setup(opts)
    end,
}

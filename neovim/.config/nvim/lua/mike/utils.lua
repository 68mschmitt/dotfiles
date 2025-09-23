local augroup = vim.api.nvim_create_augroup

local M = {}

M.augroups = {
    mike = augroup("MikeAuGroup", { clear = true }),
	filetype = augroup("UserFileType", {}),
	yank = augroup("UserYank", {}),
	windows = augroup("UserWindows", {}),
	lsp = {
		attach = augroup("UserLspAttach", {}),
		detach = augroup("UserLspDetach", {}),
		efm = augroup("UserLspEfm", {}),
		highlight = augroup("UserLspHighlight", {}),
	},
}

M.DebugLsp = function(level)
    if (level == 0) then
        return
    elseif (level == 1) then
        vim.lsp.set_log_level(vim.log.levels.WARN)
    elseif (level == 2) then
        vim.lsp.set_log_level(vim.log.levels.WARN)
    end
    vim.lsp.log.set_format_func(vim.inspect)
end

M.isWindows = function()
    local platform = vim.loop.os_uname().sysname
    return platform == "Windows_NT"
end

    -- In your Lua configuration file (e.g., init.lua or a separate module)
M.MyTabLine = function()
    local s = ''
    for i = 1, vim.fn.tabpagenr('$') do
        local buflist = vim.fn.tabpagebuflist(i)
        local winnr = vim.fn.tabpagewinnr(i)
        local bufname = vim.fn.bufname(buflist[winnr])
        local filename = vim.fn.fnamemodify(bufname, ':t') -- Get only the filename

        local tab_label = filename ~= '' and filename or '[No Name]'

        if i == vim.fn.tabpagenr() then
            s = s .. '%#TabLineSel#' -- Highlight selected tab
        else
            s = s .. '%#TabLine#' -- Default tab highlight
        end

        s = s .. ' %' .. i .. 'T' .. tab_label .. ' %X'
    end
    return s
end

return M

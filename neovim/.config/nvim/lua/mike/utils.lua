local M = {}

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

return M

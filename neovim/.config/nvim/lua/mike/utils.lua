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

return M

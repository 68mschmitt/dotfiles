local glow = {
	"ellisonleao/glow.nvim",
	cmd = "Glow",
	opts = {
		border = "none",
		width_ratio = 1.0,
		height_ratio = 1.0,
	},
	config = function(_, opts)
		local plugin = require("glow")
		plugin.setup(opts)

		-- glow.nvim always sizes its float against the whole editor. Size it to the
		-- source window instead and anchor it there, so it only covers that split.
		local execute = plugin.execute
		plugin.execute = function(cmd_opts)
			local src = vim.api.nvim_get_current_win()
			plugin.config.width = vim.api.nvim_win_get_width(src)
			plugin.config.height = vim.api.nvim_win_get_height(src)

			local open_win = vim.api.nvim_open_win
			vim.api.nvim_open_win = function(buf, enter, win_opts)
				win_opts = vim.tbl_extend("force", win_opts, { relative = "win", win = src, row = 0, col = 0 })
				return open_win(buf, enter, win_opts)
			end
			local ok, e = pcall(execute, cmd_opts)
			vim.api.nvim_open_win = open_win
			if not ok then
				error(e, 0)
			end
		end
	end,
}

return {
	glow
}

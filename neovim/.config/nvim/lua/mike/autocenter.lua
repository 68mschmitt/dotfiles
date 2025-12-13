-- ~/.config/nvim/lua/mike/autocenter.lua
local M = {}

local state = {
  enabled = false,
  align_cmd = "zz", -- "zz" (center) or "zt" (top)
}

local function center()
  if not state.enabled then return end
  if vim.fn.mode() ~= "n" then return end
  vim.cmd("normal! " .. state.align_cmd)
end

function M.setup(opts)
  opts = opts or {}

  state.enabled = opts.enabled or false
  state.align_cmd = opts.align or "zz"

  local group = vim.api.nvim_create_augroup("MikeAutoCenter", { clear = true })

  -- Center immediately when leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = center,
  })

  -- Commands
  vim.api.nvim_create_user_command("AutoCenterToggle", function()
    state.enabled = not state.enabled
    vim.notify("Auto-center: " .. (state.enabled and "ON" or "OFF"))
  end, {})

  vim.api.nvim_create_user_command("AutoCenterOn", function()
    state.enabled = true
    vim.notify("Auto-center: ON")
  end, {})

  vim.api.nvim_create_user_command("AutoCenterOff", function()
    state.enabled = false
    vim.notify("Auto-center: OFF")
  end, {})

  -- Optional keymap
  if opts.map ~= false then
    vim.keymap.set(
      "n",
      opts.keymap or "<leader>uz",
      "<cmd>AutoCenterToggle<cr>",
      { desc = "Toggle auto-center" }
    )
  end
end

return M

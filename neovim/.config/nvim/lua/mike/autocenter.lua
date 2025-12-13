-- ~/.config/nvim/lua/mike/autocenter.lua
local M = {}

local state = {
  enabled = false,
  last_insert_leave = 0,
  cooldown_ms = 400,
  align_cmd = "zz", -- can be "zz" or "zt"
}

local function now_ms()
  return vim.uv.now()
end

local function center()
  if not state.enabled then return end
  if vim.fn.mode() ~= "n" then return end

  -- prevent immediate recenter right after leaving insert
  if now_ms() - state.last_insert_leave < state.cooldown_ms then
    return
  end

  vim.cmd("normal! " .. state.align_cmd)
end

function M.setup(opts)
  opts = opts or {}

  -- Options
  state.enabled = opts.enabled or false
  state.cooldown_ms = opts.cooldown_ms or 400
  state.align_cmd = opts.align or "zz" -- "zz" or "zt"
  vim.opt.updatetime = opts.updatetime or 250

  -- Autocmds
  local group = vim.api.nvim_create_augroup("MikeAutoCenter", { clear = true })

  vim.api.nvim_create_autocmd("CursorHold", {
    group = group,
    callback = center,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      state.last_insert_leave = now_ms()
    end,
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

-- ~/.config/nvim/lua/mike/note-mode.lua
-- Note Mode: Combines auto-center and auto-wrap for better note-taking experience
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

  local group = vim.api.nvim_create_augroup("MikeNoteMode", { clear = true })

  -- Auto-center: Center immediately when leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = center,
  })

  -- Auto-wrap: Wrap at 160-170 columns when taking notes in markdown
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    pattern = { "*.md", "*.markdown" },
    desc = "Auto-wrap at 160-170 columns on space in markdown (Note Mode)",
    callback = function()
      if not state.enabled then return end

      -- Check if the character being inserted is a space
      if vim.v.char == ' ' then
        local line = vim.api.nvim_get_current_line()
        local line_len = #line

        -- If current line length is between 160-170, break to new line
        if line_len >= 160 and line_len <= 170 then
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
  end, {})

  vim.api.nvim_create_user_command("NoteModeOn", function()
    state.enabled = true
    vim.notify("Note Mode: ON")
  end, {})

  vim.api.nvim_create_user_command("NoteModeOff", function()
    state.enabled = false
    vim.notify("Note Mode: OFF")
  end, {})

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

-- octo-dump.lua — write the current octo.nvim PR context to <cwd>/.pi/octo-ctx.json
-- so pi (running in the other pane) knows which PR you are looking at and where.
--
-- Source once from your nvim config:
--   vim.cmd('luafile ' .. vim.fn.expand('~/.pi/agent/skills/octo-review/scripts/octo-dump.lua'))
--
-- Registers :PiOctoDump and an autocmd that keeps .pi/octo-ctx.json fresh as you
-- navigate octo buffers. Depends only on octo's stable accessors (buffer.node.number,
-- buffer.repo), preferring octo.context when present, falling back to octo.utils.

local function current_octo_buffer()
  local ok_ctx, ctx = pcall(require, "octo.context")
  if ok_ctx and type(ctx.get_current_buffer) == "function" then
    local b = ctx.get_current_buffer()
    if b then return b end
  end
  local ok_utils, utils = pcall(require, "octo.utils")
  if ok_utils and type(utils.get_current_buffer) == "function" then
    return utils.get_current_buffer()
  end
  return nil
end

local function current_review_file()
  local ok, reviews = pcall(require, "octo.reviews")
  if not ok then return nil end
  local layout = reviews.get_current_layout and reviews.get_current_layout()
  if not layout then return nil end
  -- API varies across octo versions; try the common shapes, tolerate all failures.
  local getters = {
    function() return layout:get_current_file().path end,
    function() return layout.file_panel:get_file_at_cursor().path end,
    function() return layout.files[1].path end,
  }
  for _, g in ipairs(getters) do
    local okp, path = pcall(g)
    if okp and type(path) == "string" then return path end
  end
  return nil
end

local function dump()
  local out = { repo = nil, number = nil, kind = nil, file = nil, line = nil }
  local b = current_octo_buffer()
  if b then
    out.repo = b.repo
    out.number = b.number or (b.node and b.node.number) or nil
    local okpr, is_pr = pcall(function() return b:isPullRequest() end)
    out.kind = (okpr and is_pr) and "pull" or "other"
  end
  out.file = current_review_file()
  local okcur, cur = pcall(vim.api.nvim_win_get_cursor, 0)
  if okcur then out.line = cur[1] end

  local dir = vim.fn.getcwd() .. "/.pi"
  vim.fn.mkdir(dir, "p")
  local fd, err = io.open(dir .. "/octo-ctx.json", "w")
  if not fd then
    vim.notify("pi octo-dump: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  fd:write(vim.json.encode(out))
  fd:close()
  return out
end

vim.api.nvim_create_user_command("PiOctoDump", function()
  local out = dump()
  if out then
    vim.notify("pi: octo context dumped (PR #" .. tostring(out.number or "?") .. ")")
  end
end, { desc = "Write current octo PR context to .pi/octo-ctx.json for pi" })

-- Keep it fresh automatically while navigating octo buffers.
local grp = vim.api.nvim_create_augroup("PiOctoDump", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
  group = grp,
  pattern = "octo://*",
  callback = function() pcall(dump) end,
  desc = "pi: refresh octo context for the review co-pilot",
})

return { dump = dump }

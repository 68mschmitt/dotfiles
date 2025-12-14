-- lua/mike/surround_wrap.lua
local M = {}

local function wrap_maps(lhs, open, close)
  close = close or open

  -- Normal: wrap word under cursor
  -- Uses: ciw + paste unnamed register + close
  vim.keymap.set("n", lhs, string.format('ciw%s<C-r>"%s<Esc>', open, close), {
    desc = string.format("Wrap word with %s…%s", open, close),
  })

  -- Visual: wrap selection
  -- Uses: change selection + paste unnamed register + close
  vim.keymap.set("v", lhs, string.format('c%s<C-r>"%s<Esc>', open, close), {
    desc = string.format("Wrap selection with %s…%s", open, close),
  })
end

function M.setup()
  -- quotes / inline code
  wrap_maps("<leader>`", "`")
  wrap_maps("<leader>'", "'")
  wrap_maps('<leader>"', '"')

  -- bracket pairs (I like grouping them under <leader>s...)
  wrap_maps("<leader>{{", "{", "}")
  wrap_maps("<leader>((", "(", ")")
  wrap_maps("<leader>[[", "[", "]")
  wrap_maps("<leader><<", "<", ">")

  -- markdown-ish
  wrap_maps("<leader>s1", "*")      -- italics: *text*
  wrap_maps("<leader>s2", "**")     -- bold: **text**

  -- Optional: fenced code block style (puts selection/word on its own lines)
  -- These feel *amazing* for notes in markdown.
  vim.keymap.set("v", "<leader>sf", "c```\n<C-r>\"```\n<Esc>", { desc = "Fence selection with ``` block" })
  vim.keymap.set("n", "<leader>sf", "ciw```\n<C-r>\"```\n<Esc>", { desc = "Fence word with ``` block" })
end

return M

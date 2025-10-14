local config = {
  fps = 10,
  name = "slide_left_safe",
}

config.update = function(grid)
  for i = 1, #grid do
    local row = grid[i]
    if #row > 0 then
      local first = row[1]
      for j = 1, #row - 1 do
        row[j] = row[j + 1]
      end
      row[#row] = first
    end
  end

  return true
end

local M = {}

function M.register()
  require("cellular-automaton").register_animation(config)
end

return M

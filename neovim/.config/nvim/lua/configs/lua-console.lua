local lua_console = {
  "yarospace/lua-console.nvim",
  lazy = true,
  keys = {
    { "`", desc = "Lua-console - toggle" },
    { "<Leader>`", desc = "Lua-console - attach to buffer" },
  },
  opts = {},
}

return {
    lua_console,
}

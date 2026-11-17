local ok, err = pcall(function()
  local devicons = require("nvim-web-devicons")
  local icons = require("config.file_icons")
  for _, name in ipairs({ "main.lua", "main.py", "README.md", "Makefile", ".gitignore", "archive.tar.gz", "unknown.no_such_extension" }) do
    local expected = devicons.get_icon(name, nil, { default = true })
    assert(icons.get(name) == expected, "Reuse Oil's devicon for " .. name)
    local mapping = icons.export()
    assert(mapping.default == devicons.get_default_icon().icon, "Export the configured default glyph")
    assert(mapping.extensions.lua == devicons.get_icon("file.lua", nil, { default = true }), "Export the active provider's Lua glyph")
  end
end)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS icons match installed nvim-web-devicons")
vim.cmd("qa!")

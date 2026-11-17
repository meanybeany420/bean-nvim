-- Validate installed tools and provision parsers. Run :BeanToolsInstall in
-- nvim-bean first; normal editor startup never installs language tools.
local ok, err = pcall(function()
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  vim.notify = function(message) print(message) end
  local status = require("bean.lsp").status()
  assert(#status.missing == 0, "Open nvim-bean and run :BeanToolsInstall first. Missing: " .. table.concat(status.missing, ", "))
  assert(vim.fn.executable("tree-sitter") == 1, "Tree-sitter CLI missing from isolated Mason bin")
  assert(require("bean.treesitter").install():wait(300000), "Parser installation failed")
  for _, language in ipairs(require("bean.treesitter").parsers) do
    assert(vim.treesitter.language.add(language), "Cannot load parser: " .. language)
  end
  io.stdout:write("PASS bootstrap: " .. #status.installed .. " tools installed; declared parsers load\n")
  io.stdout:flush()
end)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")

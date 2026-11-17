local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "a" }, root .. "/a.txt")
vim.fn.writefile({ "b" }, root .. "/b.txt")
local ok, err = pcall(function()
  local oil = require("oil")
  local ready = false
  oil.open(root, {}, function() ready = true end)
  assert(vim.wait(3000, function() return ready end), "Oil must load")
  for line = 1, vim.api.nvim_buf_line_count(0) do
    local entry = oil.get_entry_on_line(0, line)
    if entry and entry.name == "b.txt" then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
    end
  end
  local origin = vim.api.nvim_get_current_buf()
  local url = vim.api.nvim_buf_get_name(origin)
  require("config.recent_files").open()
  require("oil.view").delete_hidden_buffers()
  assert(not vim.api.nvim_buf_is_valid(origin), "Exercise Oil's real hidden-buffer cleanup")
  vim.fn.maparg("<Esc>", "n", false, true).callback()
  assert(vim.wait(3000, function()
    local entry = vim.bo.filetype == "oil" and oil.get_cursor_entry()
    return entry and entry.name == "b.txt"
  end), "Esc must reopen Oil and restore the selected entry after cleanup")
  assert(vim.api.nvim_buf_get_name(0) == url, "Return to the same Oil directory")
end)
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS Esc restores Oil directory and selected entry after hidden-buffer cleanup")
vim.cmd("qa!")

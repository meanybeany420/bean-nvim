-- Run: nvim --headless -u NONE -i NONE -l tests/recent_files.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local first = root .. "/first file.txt"
local second = root .. "/second.txt"
vim.fn.writefile({ "first" }, first)
vim.fn.writefile({ "second" }, second)

local ok, err = pcall(function()
  local recent = require("config.recent_files")
  vim.v.oldfiles = { second, first, second, root .. "/missing", root, "oil://" .. root }
  assert(vim.deep_equal(recent.files(), { second, first }), "History must preserve order, dedupe, and skip missing files/directories/URIs")

  vim.cmd.edit(vim.fn.fnameescape(first))
  local original = vim.api.nvim_get_current_buf()
  vim.bo.modified = true
  local old_number, old_cursorline = vim.wo.number, vim.wo.cursorline
  recent.open()
  assert(vim.bo.filetype == "bean_recent", "Open a dedicated recent-files buffer")
  assert(vim.bo.buftype == "nofile" and not vim.bo.modifiable, "List must be a read-only scratch buffer")
  assert(vim.wo.cursorline and not vim.wo.number, "List needs a cursor highlight without line numbers")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(table.concat(lines, "\n"):find("second.txt", 1, true), "Render filenames")
  local icon_prefix = "  " .. require("config.file_icons").get(second) .. "  "
  assert(lines[4]:sub(1, #icon_prefix) == icon_prefix, "Show a file-type icon before each recent filename")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 4, "Start on the first file, not the heading")
  local quit = vim.fn.maparg("q", "n", false, true)
  quit.callback()
  assert(vim.api.nvim_get_current_buf() == original and vim.bo.modified, "q must preserve and restore the modified source buffer")
  assert(vim.wo.number == old_number and vim.wo.cursorline == old_cursorline, "Restore original window options")

  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local source_view = vim.fn.winsaveview()
  recent.open()
  vim.fn.maparg("<Esc>", "n", false, true).callback()
  assert(vim.api.nvim_get_current_buf() == original, "Esc must return to the original buffer")
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 3 }), "Esc must restore the cursor position")
  assert(vim.fn.winsaveview().topline == source_view.topline and vim.bo.modified, "Esc must preserve viewport and unsaved changes")

  recent.open()
  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  vim.fn.maparg("<CR>", "n", false, true).callback()
  assert(vim.api.nvim_buf_get_name(0) == first, "Enter must safely open a filename containing spaces")
  assert(vim.bo.modified, "Opening must never discard unsaved changes")

  vim.v.oldfiles = {}
  recent.open()
  assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("No recent files", 1, true), "Show an empty state")
  vim.fn.maparg("<CR>", "n", false, true).callback()
  assert(vim.bo.filetype == "bean_recent", "Enter on empty state is harmless")
  vim.fn.maparg("q", "n", false, true).callback()

  recent.setup()
  vim.cmd("hide edit " .. vim.fn.fnameescape(second))
  vim.cmd("hide edit " .. vim.fn.fnameescape(first))
  assert(vim.deep_equal(recent.files(), { first, second }), "Current-session visits must be most-recent-first")
  vim.cmd("RecentFiles")
  assert(vim.bo.filetype == "bean_recent", "Expose a RecentFiles command")
  vim.fn.maparg("q", "n", false, true).callback()
  vim.cmd("hide edit " .. vim.fn.fnameescape(second))
  assert(vim.deep_equal(recent.files(), { second, first }), "Revisiting must move a file to the top without duplicating it")
end)
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
print("PASS recent files history")
vim.cmd("qa!")

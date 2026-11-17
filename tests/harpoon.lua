-- Isolate XDG_DATA_HOME when running: Harpoon persists its lists there.
vim.opt.rtp:prepend('/home/owen/.config/nvim-bean')
local plugins = vim.env.BEAN_TEST_PLUGIN_ROOT or '/home/owen/.local/share/nvim-bean/site/pack/core/opt'
for _, name in ipairs({ 'plenary.nvim', 'harpoon' }) do vim.opt.rtp:append(plugins .. '/' .. name) end
local root = vim.fn.tempname()
local ok, err = pcall(function()
  require('bean.options').setup()
  assert(vim.fn.filereadable(vim.fn.stdpath('config') .. '/lua/bean/harpoon.lua') == 1, 'Restore the Harpoon module')
  require('bean.harpoon').setup()
  vim.fn.mkdir(root, 'p')
  vim.uv.chdir(root)
  for i = 1, 4 do
    local path = root .. '/file' .. i .. '.txt'
    vim.fn.writefile({ 'file ' .. i }, path)
    vim.cmd.edit(path)
    vim.api.nvim_feedkeys(' a', 'xt', false)
  end
  local harpoon = require('harpoon')
  assert(#harpoon:list().items == 4, 'Space a must add actual files')
  for i = 1, 4 do
    vim.api.nvim_feedkeys(' ' .. i, 'xt', false)
    assert(vim.api.nvim_buf_get_name(0) == root .. '/file' .. i .. '.txt', 'Space ' .. i .. ' must select its file')
  end
  local original = vim.api.nvim_get_current_win()
  vim.api.nvim_feedkeys(' h', 'xt', false)
  assert(vim.api.nvim_get_current_win() ~= original, 'Space h must open the Harpoon menu')
  local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(lines:find('file1.txt', 1, true) and lines:find('file4.txt', 1, true), 'Menu must contain the marked files')
  vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'xt', false)
  assert(vim.api.nvim_get_current_win() == original, 'Esc must close the Harpoon menu')
end)
vim.fn.delete(root, 'rf')
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
io.stdout:write('PASS Harpoon: actual add, four jumps, menu contents and Esc\n')
vim.cmd('qa!')

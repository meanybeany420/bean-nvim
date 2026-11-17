local ok, err = pcall(function()
  dofile(vim.fn.stdpath('config') .. '/init.lua')
  local oil = require('oil')
  oil.setup({ cleanup_delay_ms = 30 })
  local root = vim.fn.tempname() .. " quote's $USER"
  vim.fn.mkdir(root .. '/inside', 'p')
  vim.fn.mkdir(root .. '/.git', 'p')
  vim.fn.writefile({ 'inside_token' }, root .. '/inside/selected.txt')
  vim.fn.writefile({ 'outside_token' }, root .. '/outside.txt')
  oil.open(root .. '/inside')
  assert(vim.wait(3000, function()
    return oil.get_entry_on_line(0, 1) ~= nil
  end), 'Wait for real Oil directory')
  local selected_line
  for line = 1, vim.api.nvim_buf_line_count(0) do
    local entry = oil.get_entry_on_line(0, line)
    if entry and entry.name == 'selected.txt' then selected_line = line; break end
  end
  assert(selected_line, 'Find actual Oil entry')
  vim.api.nvim_win_set_cursor(0, { selected_line, 0 })
  local origin, url = vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0)
  assert(require('config.project_grep').root():gsub('/$', '') == root .. '/inside', 'From Oil search current directory, not parent project')
  vim.api.nvim_feedkeys(' /', 'xt', false)
  assert(vim.bo.filetype == 'bean_grep', 'Actual Space / opens content search')
  local term, channel = vim.api.nvim_get_current_buf(), vim.b.terminal_job_id
  assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('Search>', 1, true)
  end), 'Real fzf must start')
  vim.api.nvim_chan_send(channel, 'outside_token')
  vim.wait(300, function() return false end)
  local screen = table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n')
  assert(not screen:find('outside.txt', 1, true), 'Never search above current Oil directory')
  vim.api.nvim_chan_send(channel, '\21inside_token')
  assert(vim.wait(3000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('selected.txt', 1, true)
  end), 'Changing query must show actual in-scope match')
  assert(vim.wait(3000, function() return not vim.api.nvim_buf_is_valid(origin) end), 'Exercise real hidden-Oil buffer cleanup')
  vim.api.nvim_chan_send(channel, '\27')
  assert(vim.wait(3000, function()
    local entry = oil.get_cursor_entry()
    return vim.api.nvim_buf_get_name(0) == url and entry and entry.name == 'selected.txt'
  end), 'One Esc must reopen Oil and restore exact selected entry')
  assert(not vim.api.nvim_buf_is_valid(term), 'Dispose search terminal')
  vim.fn.delete(root, 'rf')
end)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
io.stdout:write('PASS Oil content search: Space /, correct scope, live query changes, actual cleanup and Esc selection restoration\n')
vim.cmd('qa!')

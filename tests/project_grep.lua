vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname() .. " quote's $USER project"
local source = root .. '/src/source.txt'
local target = root .. "/src/needle 'file': [1].txt"
vim.fn.mkdir(root .. '/.git', 'p')
vim.fn.mkdir(root .. '/src/deep', 'p')
vim.fn.writefile({ 'source' }, source)
vim.fn.writefile({ 'first line', 'prefix check_password(value)' }, target)
local cwd = vim.fn.getcwd()
local ok, err = pcall(function()
  assert(vim.fn.filereadable(cwd .. '/lua/config/project_grep.lua') == 1, 'Implement project content search')
  local search = require('config.project_grep')
  vim.cmd.edit(vim.fn.fnameescape(source))
  assert(search.root() == root, 'Find nearest ancestor marker, preserving literal dollar signs')
  vim.fn.writefile({ '{}' }, root .. '/src/package.json')
  assert(search.root() == root .. '/src', 'Nearest nested project marker wins')
  vim.fn.delete(root .. '/src/package.json')
  vim.fn.delete(root .. '/.git', 'd')
  -- The host home is itself a Git root. Isolate the no-marker branch without
  -- modifying that repository or placing fixtures outside the scratch tree.
  local stat = vim.uv.fs_stat
  vim.uv.fs_stat = function() return nil end
  local fallback = search.root()
  vim.uv.fs_stat = stat
  assert(fallback == root .. '/src', 'Without markers use file directory, not unrelated cwd')
  vim.fn.mkdir(root .. '/.git', 'p')
  local origin = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(origin, 0, -1, false, { 'unsaved source' })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local function launch(query)
    search.open()
    assert(vim.bo.filetype == 'bean_grep', 'Open full-window content search directly')
    local term = vim.api.nvim_get_current_buf()
    assert(vim.wait(5000, function()
      return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('Search>', 1, true)
    end), 'Real fzf must show its prompt')
    local channel = vim.b.terminal_job_id
    if query then vim.api.nvim_chan_send(channel, query) end
    return channel, term
  end
  local channel, term = launch('check_password')
  assert(vim.wait(5000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('prefix check_password', 1, true)
  end), 'Typing must reload real ripgrep results')
  vim.api.nvim_chan_send(channel, '\r')
  assert(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) == target end), 'Enter must open the exact filename')
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.api.nvim_win_get_cursor(0)[2] == 7, 'Jump to matching line and byte column')
  assert(vim.bo[origin].modified, 'Preserve unsaved source')
  local literal = "$(touch OWNED) ' [x] $USER; & |"
  local literal_path = root .. '/literal.txt'
  vim.fn.writefile({ literal }, literal_path)
  channel, term = launch(literal)
  assert(vim.wait(5000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('literal.txt', 1, true)
  end), 'Live reload must quote shell metacharacters and use literal text search')
  assert(vim.fn.filereadable(root .. '/OWNED') == 0, 'Query text must never execute as shell code')
  vim.api.nvim_chan_send(channel, '\r')
  assert(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) == literal_path end), 'Open literal-query match')
  vim.api.nvim_win_set_buf(0, origin)
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  channel, term = launch('no_such_content')
  vim.api.nvim_chan_send(channel, '\27')
  assert(vim.wait(5000, function() return vim.api.nvim_get_current_buf() == origin end), 'One Esc restores original file')
  assert(vim.api.nvim_win_get_cursor(0)[2] == 3 and vim.bo.modified, 'Restore cursor and unsaved work')
  assert(not vim.api.nvim_buf_is_valid(term), 'Cancellation wipes the terminal')
  channel, term = launch()
  vim.cmd.stopinsert()
  vim.api.nvim_win_set_buf(0, origin)
  assert(vim.wait(3000, function() return not vim.api.nvim_buf_is_valid(term) end), 'Abandonment cleans scratch buffer')
  assert(vim.wait(3000, function() return vim.fn.jobwait({channel}, 0)[1] ~= -1 end), 'Abandonment stops actual process')
  assert(vim.api.nvim_get_current_buf() == origin, 'Late callbacks cannot resurrect search')
end)
vim.uv.chdir(cwd)
vim.fn.delete(root, 'rf')
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
io.stdout:write('PASS content search: roots, live rg/fzf, exact file/line/column, unsaved work, Esc and abandonment\n')
vim.cmd('qa!')

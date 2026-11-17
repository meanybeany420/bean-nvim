local M = {}
local markers = { '.git', 'go.mod', 'package.json', 'pyproject.toml', 'Cargo.toml',
  'Makefile', 'CMakeLists.txt', 'pom.xml', 'build.gradle', 'build.gradle.kts' }

function M.root()
  if vim.bo.filetype == 'oil' then
    return require('oil').get_current_dir()
  end
  local filename = vim.api.nvim_buf_get_name(0)
  local start = vim.bo.buftype == '' and filename ~= '' and vim.fs.dirname(filename) or vim.fn.getcwd()
  local directory = start
  while directory do
    for _, marker in ipairs(markers) do
      if vim.uv.fs_stat(vim.fs.joinpath(directory, marker)) then return directory end
    end
    local parent = vim.fs.dirname(directory)
    directory = parent ~= directory and parent or nil
  end
  return start
end

function M.open()
  if vim.bo.filetype == 'bean_grep' then return end
  local root = M.root()
  if not root or vim.fn.isdirectory(root) ~= 1 then
    vim.notify('Content search needs a local directory', vim.log.levels.WARN)
    return
  end
  for _, executable in ipairs({ 'rg', 'fzf', 'python3' }) do
    if vim.fn.executable(executable) ~= 1 then
      vim.notify('Content search requires ' .. executable, vim.log.levels.ERROR)
      return
    end
  end
  local view = require('config.file_finder').view
  local state = view.capture()
  local term = vim.api.nvim_create_buf(false, true)
  local result = vim.fn.tempname()
  local active, job, winclosed = true, nil, nil
  local function cleanup()
    active = false
    if winclosed then pcall(vim.api.nvim_del_autocmd, winclosed); winclosed = nil end
    if job then vim.fn.jobstop(job); job = nil end
    vim.fn.delete(result)
    view.restore_options(state)
    if vim.api.nvim_buf_is_valid(term) then vim.api.nvim_buf_delete(term, { force = true }) end
  end
  local function check_left()
    vim.schedule(function()
      if active and (not vim.api.nvim_win_is_valid(state.win) or vim.api.nvim_win_get_buf(state.win) ~= term) then
        cleanup()
      end
    end)
  end
  vim.api.nvim_create_autocmd('BufWinLeave', { buffer = term, callback = check_left })
  winclosed = vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(state.win), once = true, callback = function() vim.schedule(cleanup) end,
  })
  vim.api.nvim_win_set_buf(state.win, term)
  vim.bo[term].bufhidden = 'wipe'
  vim.bo[term].filetype = 'bean_grep'
  for key, value in pairs({ number = false, relativenumber = false, cursorline = false,
    signcolumn = 'no', foldcolumn = '0', list = false, wrap = false, spell = false }) do
    vim.api.nvim_set_option_value(key, value, { win = state.win })
  end
  local header = 'Search contents · ' .. vim.fn.strtrans(root)
    .. '\nType text · Enter open · Esc back · Ctrl-j/k move · smart case'
  job = vim.fn.jobstart({ 'python3', vim.fn.stdpath('config') .. '/scripts/bean-grep.py',
    'ui', root, result, view.colours(), header }, {
    term = true, cwd = root,
    on_exit = function(_, code)
      vim.schedule(function()
        local file = io.open(result, 'rb')
        local output = file and file:read('*a') or ''
        if file then file:close() end
        vim.fn.delete(result)
        job = nil
        if not active then return end
        if not vim.api.nvim_win_is_valid(state.win) or vim.api.nvim_win_get_buf(state.win) ~= term then
          cleanup()
          return
        end
        active = false
        vim.api.nvim_win_call(state.win, function()
          vim.cmd.stopinsert()
          view.restore_options(state)
          local record = output:match('^(.-)%z')
          local decoded, match = pcall(vim.json.decode, record and record:match('^[^\t]+') or '')
          local path
          if code == 0 and decoded and type(match) == 'table' and type(match.path) == 'string'
            and type(match.line) == 'number' and type(match.column) == 'number' then
            local valid, relative = pcall(vim.base64.decode, match.path)
            if valid then path = vim.fs.joinpath(root, relative) end
          end
          if path and vim.fn.filereadable(path) == 1 then
            vim.cmd('hide edit ' .. vim.fn.fnameescape(path))
            local line = math.max(1, math.min(match.line, vim.api.nvim_buf_line_count(0)))
            local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
            vim.api.nvim_win_set_cursor(0, { line, math.max(0, math.min(match.column - 1, #text)) })
            vim.cmd.normal({ 'zvzz', bang = true })
          else
            view.restore(state)
            if path then
              vim.notify('Search match is no longer readable: ' .. vim.fn.strtrans(path), vim.log.levels.WARN)
            elseif code ~= 0 and code ~= 1 and code ~= 130 and code ~= 143 then
              vim.notify('Content search exited with status ' .. code, vim.log.levels.ERROR)
            end
          end
        end)
        cleanup()
      end)
    end,
  })
  if job <= 0 then
    job = nil
    view.restore(state)
    cleanup()
    vim.notify('Could not start content search', vim.log.levels.ERROR)
    return
  end
  local running = job
  vim.keymap.set('t', '<Esc>', function() vim.api.nvim_chan_send(running, '\27') end,
    { buffer = term, silent = true, nowait = true })
  vim.keymap.set('n', '<Esc>', function() vim.fn.jobstop(running) end,
    { buffer = term, silent = true, nowait = true })
  vim.cmd.startinsert()
end

return M

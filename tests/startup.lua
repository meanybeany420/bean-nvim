-- Use as -u tests/startup.lua, with no file argument or a scratch file.
local ok, err = pcall(function()
  dofile(vim.fn.stdpath('config') .. '/init.lua')
  if vim.fn.argc() == 0 then
    assert(vim.api.nvim_buf_get_name(0):match('^oil://'), 'Oil must be the initial buffer before VimEnter, not scheduled afterwards')
  end
end)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
  local passed, problem = pcall(function()
    if vim.fn.argc() == 0 then
      assert(vim.bo.filetype == 'oil', 'Empty launch must enter Oil')
    else
      local actual, expected = vim.api.nvim_buf_get_name(0), vim.fn.argv(0)
      if expected:sub(1, 1) ~= '/' then expected = vim.fn.getcwd() .. '/' .. expected end
      expected = vim.fs.normalize(expected, { expand_env = false })
      assert(actual == expected, 'Explicit file argument must not be replaced by Oil: ' .. vim.inspect({ actual = actual, expected = expected }))
    end
  end)
  if not passed then io.stderr:write(tostring(problem) .. '\n'); vim.cmd('cquit 1') end
  io.stdout:write('PASS startup: correct initial buffer, no deferred explorer switch\n')
  vim.cmd('qa!')
end })

vim.opt.rtp:prepend(vim.fn.stdpath('config'))
local ok, err = pcall(function()
  require('bean.options').setup()
  assert(vim.o.timeout and vim.o.timeoutlen == 1000, 'Allow one second between leader and the next key')
  assert(vim.o.ttimeoutlen == 10, 'Keep terminal-key decoding responsive')
end)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
io.stdout:write('PASS options: one-second mapping timeout; terminal-key timeout unchanged\n')
vim.cmd('qa!')

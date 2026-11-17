local M = {}

function M.specs()
  local path = vim.fn.stdpath("config") .. "/packages.json"
  return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end

function M.setup()
  assert(vim.pack and vim.pack.add, "nvim-bean requires Neovim's native package manager (0.12+)")
  vim.pack.add(M.specs(), { confirm = false, load = true })
end

return M

local M = {}

function M.setup()
  vim.cmd("filetype plugin indent on")
  vim.cmd("syntax enable")
  vim.g.mapleader = " "
  vim.g.maplocalleader = "\\"
  local options = {
    termguicolors = true, background = "dark",
    number = true, relativenumber = true, cursorline = false,
    scrolloff = 8, sidescrolloff = 8,
    expandtab = true, shiftwidth = 2, tabstop = 2, smartindent = true,
    ignorecase = true, smartcase = true, incsearch = true,
    wrap = false, splitright = true, splitbelow = true,
    signcolumn = "yes", laststatus = 3, showmode = false, showtabline = 0,
    updatetime = 200, timeout = true, timeoutlen = 1000, ttimeoutlen = 10,
    undofile = true, swapfile = false, clipboard = "unnamedplus",
    mouse = "a", conceallevel = 2, pumheight = 10,
    completeopt = "menu,menuone,noselect", winborder = "rounded",
  }
  for name, value in pairs(options) do
    vim.opt[name] = value
  end
  vim.opt.fillchars:append({ eob = " ", fold = " " })
  vim.opt.shortmess:append("c")
end

return M

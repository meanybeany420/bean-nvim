local M = {}

M.parsers = { "c", "cpp", "go", "gomod", "gosum", "python", "java", "bash", "lua", "markdown", "markdown_inline", "vim", "vimdoc", "query", "json", "yaml", "toml", "html", "css", "javascript", "typescript", "tsx", "rust" }

function M.install()
  assert(vim.fn.executable("tree-sitter") == 1, "Run :BeanToolsInstall first to install the Tree-sitter CLI")
  return require("nvim-treesitter").install(M.parsers, { max_jobs = 4, summary = true })
end

function M.setup()
  require("nvim-treesitter").setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
  local group = vim.api.nvim_create_augroup("BeanTreesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(event)
      if vim.bo[event.buf].buftype == "" then
        pcall(vim.treesitter.start, event.buf)
      end
    end,
  })
end

return M

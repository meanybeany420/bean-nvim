local M = {}

function M.setup()
  require("conform").setup({
    formatters_by_ft = {
      lua = { "stylua" },
      go = { "goimports", "gofumpt" },
      python = { "ruff_format" },
      c = { "clang_format" }, cpp = { "clang_format" },
      sh = { "shfmt" }, bash = { "shfmt" },
    },
    format_on_save = function(buf)
      if vim.bo[buf].buftype ~= "" or vim.g.bean_autoformat == false then
        return
      end
      return { timeout_ms = 1500, lsp_format = "fallback" }
    end,
    default_format_opts = { lsp_format = "fallback" },
  })
end

return M
